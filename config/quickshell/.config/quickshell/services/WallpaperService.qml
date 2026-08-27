// services/WallpaperService.qml
// Datos y acciones del picker de wallpapers (waywallen vía D-Bus + DB SQLite).
// Todo lo D-Bus se hace con busctl a través de Quickshell.Io.Process (este
// build de Quickshell no trae Quickshell.DBus). La carpeta son organizativas
// client-side (JSON), nunca se escriben playlists/tags en la DB de waywallen.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ============================================================
    // CONFIG
    // ============================================================
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string scriptsBin: homeDir + "/.local/bin"
    readonly property string dbPath: homeDir + "/.local/share/waywallen/waywallen-v2.db"
    readonly property string thumbCacheDir: homeDir + "/.cache/wallpaper_previews/thumbs"
    readonly property string foldersPath: homeDir + "/.config/quickshell/wallpaper-folders.json"

    readonly property string daemonBus: "org.waywallen.waywallen.Daemon"
    readonly property string daemonObj: "/org/waywallen/waywallen/Daemon"
    readonly property string daemonIface: "org.waywallen.waywallen.Daemon1"

    // ============================================================
    // ESTADO: datos
    // ============================================================
    property var items: []          // [{id, name, type, preview, thumb, tags[..]}]
    property var tagNames: []
    property string currentId: ""
    property bool daemonUp: false
    property bool loading: false

    // ============================================================
    // ESTADO: ventana + filtros
    // ============================================================
    property bool open: false
    property bool active: false

    property string activeFolder: "all"   // "all" | "unfiled" | nombre de carpeta
    property string activeType: "all"
    property string activeTag: ""
    property string searchText: ""

    // ============================================================
    // ESTADO: acciones
    // ============================================================
    property string applyingId: ""
    property string applyResult: ""
    property bool applyFailed: false
    property bool shuffle: false
    property bool cmdBusy: false
    property bool thumbsReady: false

    property var _beforeAdvance: ""
    property int _advanceTicks: 0
    property var _pendingFolders: null
    property var _pendingApply: ""

    // ============================================================
    // VISTA COMPUTADA
    // ============================================================
    property var visibleItems: root.computeVisible()

    function computeVisible() {
        const q = root.searchText.trim().toLowerCase()
        const out = []
        for (let i = 0; i < root.items.length; ++i) {
            const it = root.items[i]
            if (root.activeType !== "all" && it.type !== root.activeType)
                continue
            if (root.activeTag && (!it.tags || it.tags.indexOf(root.activeTag) < 0))
                continue
            if (q && it.name.toLowerCase().indexOf(q) < 0)
                continue
            if (root.activeFolder !== "all" && !root.isVisibleInFolder(it.id, root.activeFolder))
                continue
            out.push(it)
        }
        return out
    }

    function isVisibleInFolder(id, folderName) {
        if (folderName === "unfiled")
            return !root.itemInAnyFolder(id)
        return root.itemInFolder(id, folderName)
    }

    function itemInFolder(id, folderName) {
        for (let f = 0; f < root.folders.length; ++f) {
            const folder = root.folders[f]
            if (folder.name === folderName)
                return folder.ids.indexOf(String(id)) >= 0
        }
        return false
    }

    function itemInAnyFolder(id) {
        for (let f = 0; f < root.folders.length; ++f) {
            if (root.folders[f].ids.indexOf(String(id)) >= 0)
                return true
        }
        return false
    }

    function folderCount(folderName) {
        if (folderName === "unfiled") {
            let n = 0
            for (let i = 0; i < root.items.length; ++i) {
                if (!root.itemInAnyFolder(root.items[i].id))
                    ++n
            }
            return n
        }
        for (let f = 0; f < root.folders.length; ++f) {
            if (root.folders[f].name === folderName)
                return root.folders[f].ids.length
        }
        return 0
    }

    function thumbPath(id) {
        return root.thumbCacheDir + "/" + id + ".jpg"
    }

    function nameForId(id) {
        for (let i = 0; i < root.items.length; ++i) {
            if (root.items[i].id === String(id))
                return root.items[i].name
        }
        return ""
    }

    // ============================================================
    // VENTANA
    // ============================================================
    // Nota: `open` es una propiedad booleana (línea 39); abrir/cerrar se hace
    // asignándola, por eso no existe aquí un método `open()` (lo sombrearía).
    function close() { root.open = false }
    function toggle() { root.open = !root.open }

    onOpenChanged: {
        root.active = root.open
        if (root.open) {
            if (!root.items.length)
                root.loadItems()
            root.refreshCurrentId()
            root.ensureThumbs()
        }
    }

    // ============================================================
    // ITEMS (DB de waywallen)
    // ============================================================
    function loadItems() {
        root.loading = true
        const sql = "SELECT i.id, i.display_name, i.type, l.path || '/' || i.preview_path, " +
            "COALESCE((SELECT group_concat(t.name, ',') FROM item_tag it JOIN tag t ON t.id = it.tag_id " +
            "WHERE it.item_id = i.id), '') " +
            "FROM item i JOIN library l ON l.id = i.library_id " +
            "WHERE i.plugin_id = 4 AND i.preview_path LIKE 'steamapps/workshop/%' " +
            "ORDER BY lower(i.display_name);"
        itemsProcess.command = ["sqlite3", "-readonly", "-separator", "\t", root.dbPath, sql]
        itemsProcess.running = false
        itemsProcess.running = true
    }

    function parseItems(text) {
        const rows = text.trim().split("\n")
        const out = []
        for (let i = 0; i < rows.length; ++i) {
            const parts = rows[i].split("\t")
            if (parts.length < 4 || !parts[0])
                continue
            out.push({
                id: parts[0],
                name: parts[1],
                type: parts[2],
                preview: parts[3],
                thumb: root.thumbPath(parts[0]),
                tags: parts[4] ? parts[4].split(",") : []
            })
        }
        return out
    }

    function extractTags(items) {
        const seen = {}
        const out = []
        for (let i = 0; i < items.length; ++i) {
            const tags = items[i].tags
            for (let t = 0; t < tags.length; ++t) {
                if (!seen[tags[t]]) {
                    seen[tags[t]] = true
                    out.push(tags[t])
                }
            }
        }
        out.sort()
        return out
    }

    property Process itemsProcess: Process {
        stdout: StdioCollector {
            id: itemsCollector
            onStreamFinished: {
                root.loading = false
                const parsed = root.parseItems(itemsCollector.text)
                if (parsed.length > 0) {
                    root.items = parsed
                    root.tagNames = root.extractTags(parsed)
                }
            }
        }
    }

    function ensureThumbs() {
        if (root.thumbsReady || thumbsProcess.running)
            return
        thumbsProcess.command = ["bash", root.scriptsBin + "/wallpaper-thumbs.sh"]
        thumbsProcess.running = true
    }

    property Process thumbsProcess: Process {
        onExited: () => {
            root.thumbsReady = true
        }
    }

    // ============================================================
    // CARPETAS (client-side JSON, reactivo)
    // ============================================================
    property FileView foldersFile: FileView {
        path: Qt.resolvedUrl("file://" + root.foldersPath)
        blockLoading: true
        watchChanges: true

        onFileChanged: reload()
    }

    property var folders: root.parseFolders(root.foldersFile.text())

    function parseFolders(text) {
        try {
            const obj = JSON.parse(text)
            return (obj && Array.isArray(obj.folders)) ? obj.folders : []
        } catch (e) {
            return []
        }
    }

    function runFolders(args) {
        if (foldersProcess.running) {
            root._pendingFolders = args
            return
        }
        root._runFolders(args)
    }

    function _runFolders(args) {
        foldersProcess.command = ["bash", root.scriptsBin + "/wallpaper-folders.sh"].concat(args)
        foldersProcess.running = true
    }

    function createFolder(name) {
        const n = name.trim()
        if (n) root.runFolders(["new", n])
    }

    function deleteFolder(name) {
        root.runFolders(["rm", name])
        if (root.activeFolder === name)
            root.activeFolder = "all"
    }

    function addItemToFolder(id, folderName) {
        root.runFolders(["add", folderName, String(id)])
    }

    function removeItemFromFolder(id, folderName) {
        root.runFolders(["remove", folderName, String(id)])
    }

    function toggleItemInFolder(id, folderName) {
        if (root.itemInFolder(id, folderName))
            root.removeItemFromFolder(id, folderName)
        else
            root.addItemToFolder(id, folderName)
    }

    function initFolders() {
        root.runFolders(["init"])
    }

    property Process foldersProcess: Process {
        onExited: () => {
            if (root._pendingFolders) {
                const args = root._pendingFolders
                root._pendingFolders = null
                root._runFolders(args)
            }
        }
    }

    // ============================================================
    // WAYWALLEN: estado actual + aplicación
    // ============================================================
    function refreshCurrentId() {
        if (currentProcess.running)
            return
        currentProcess.command = ["busctl", "--user", "get-property",
            root.daemonBus, root.daemonObj, root.daemonIface, "CurrentWallpaperId"]
        currentProcess.running = true
    }

    property Process currentProcess: Process {
        stdout: StdioCollector {
            id: currentCollector
            onStreamFinished: {
                const m = currentCollector.text.match(/"(\d+)"/)
                root.currentId = m ? m[1] : ""
                root.daemonUp = !!m
                root._afterCurrentRefresh()
            }
        }
    }

    function _afterCurrentRefresh() {
        if (advancePollTimer.running) {
            if (root.currentId && root.currentId !== root._beforeAdvance) {
                advancePollTimer.stop()
                root.cmdBusy = false
                root.apply(root.currentId, true)
            } else {
                ++root._advanceTicks
                if (root._advanceTicks >= 20) {
                    advancePollTimer.stop()
                    root.cmdBusy = false
                }
            }
        }
    }

    // Aplica un item por id usando el pipeline completo (wallpaper.sh).
    // `keepOpen = true` se usa para Next/Previous (seguir navegando);
    // con aplicaciones normales (click/Enter) la ventana se cierra al terminar.
    function apply(id, keepOpen) {
        if (root.applyingId || !id)
            return
        root.applyFailed = false
        root.applyResult = ""
        root.applyingId = String(id)
        root._keepOpenAfterApply = keepOpen === true
        applyProcess.command = ["bash", root.scriptsBin + "/wallpaper.sh", String(id)]
        applyProcess.running = true
    }

    property bool _keepOpenAfterApply: false

    property Process applyProcess: Process {
        stdout: StdioCollector {
            id: applyCollector
            onStreamFinished: {
                root.applyResult = applyCollector.text.trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.applyingId = ""
            root.applyFailed = exitCode !== 0
            root.refreshCurrentId()
            // Solo cerrar tras un apply normal y con éxito: con Next/Previous
            // (keepOpen) se queda en la ventana para seguir navegando.
            if (exitCode === 0 && !root._keepOpenAfterApply) {
                root._keepOpenAfterApply = false
                closeAfterApplyTimer.start()
            } else {
                root._keepOpenAfterApply = false
            }
        }
    }

    property Timer closeAfterApplyTimer: Timer {
        interval: 350
        repeat: false
        onTriggered: root.close()
    }

    // ============================================================
    // CONTROL: siguiente/anterior
    // ============================================================
    function next() { root._advance("Next") }
    function previous() { root._advance("Previous") }

    function _advance(method) {
        if (root.cmdBusy || root.applyingId)
            return
        root.cmdBusy = true
        root._beforeAdvance = root.currentId
        root._advanceTicks = 0
        advProcess.command = ["busctl", "--user", "call",
            root.daemonBus, root.daemonObj, root.daemonIface, method]
        advProcess.running = true
    }

    property Process advProcess: Process {
        onExited: () => {
            advancePollTimer.start()
        }
    }

    property Timer advancePollTimer: Timer {
        interval: 350
        repeat: true
        onTriggered: root.refreshCurrentId()
    }

    function rescan() {
        if (root.cmdBusy)
            return
        root.cmdBusy = true
        rescanProcess.command = ["busctl", "--user", "call",
            root.daemonBus, root.daemonObj, root.daemonIface, "Rescan"]
        rescanProcess.running = true
    }

    property Process rescanProcess: Process {
        onExited: () => {
            root.cmdBusy = false
            rescanReloadTimer.start()
        }
    }

    property Timer rescanReloadTimer: Timer {
        interval: 1600
        onTriggered: {
            root.loadItems()
            root.ensureThumbs()
        }
    }

    // ============================================================
    // CONTROL: shuffle
    // ============================================================
    function setShuffle(on) {
        if (root.shuffle === on)
            return
        root.shuffle = on
        shuffleProcess.command = ["busctl", "--user", "call",
            root.daemonBus, root.daemonObj, root.daemonIface, "SetShuffle", "b",
            on ? "true" : "false"]
        shuffleProcess.running = true
    }

    property Process shuffleProcess: Process {
        command: []
        running: false
    }

    // ============================================================
    // REFRESH PERIÓDICO (solo con la ventana abierta)
    // ============================================================
    property Timer periodicTimer: Timer {
        interval: 5000
        repeat: true
        running: root.active
        onTriggered: {
            if (!applyProcess.running)
                root.refreshCurrentId()
        }
    }

    Component.onCompleted: {
        root.initFolders()
        root.ensureThumbs()
        refreshTimer.start()
    }

    // Pequeño retraso para que la sesión D-Bus esté lista tras arrancar.
    property Timer refreshTimer: Timer {
        interval: 800
        repeat: false
        onTriggered: {
            root.refreshCurrentId()
        }
    }
}