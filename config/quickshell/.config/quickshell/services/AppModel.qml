import QtQuick
import Quickshell
import Quickshell.Io
// services/AppModel.qml
// Datos del launcher Gear: escanea los .desktop (vía scripts/list-apps.sh) y
// mantiene `apps` (TODO, para el anillo y la búsqueda). `offset` es el índice
// en apps (app del foco). Toda la navegación del anillo y el lanzamiento viven
// aquí.
pragma Singleton

Singleton {
    id: root

    // ============================================================
    // CONFIG
    // ============================================================
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string scriptsDir: homeDir + "/.config/quickshell/scripts"
    // ============================================================
    // ESTADO: apps
    // ============================================================
    property var apps: []
    // [{path, name, icon, exec, keywords, terminal}]
    property bool loaded: false
    property bool loading: false
    // Anillo: TODAS las apps se muestran en el engranaje (sin filtro de icono).
    readonly property var ringApps: root.apps
    readonly property int ringCount: root.ringApps.length
    // ============================================================
    // ESTADO: anillo
    // offset ∈ [0, ringCount): app del hub (diente 0). El diente k (0..N-1)
    // muestra ringApps[mod(offset + k, ringCount)].
    // ============================================================
    property int offset: 0
    readonly property int count: root.apps.length
    property Process scanProcess
    property bool launchError: false
    property Process launchProcess
    property Process usageProcess

    function mod(a, b) {
        return ((a % b) + b) % b;
    }

    function refresh() {
        if (root.loading)
            return ;

        root.loading = true;
        root.loaded = false;
        scanProcess.command = ["bash", root.scriptsDir + "/list-apps.sh"];
        scanProcess.running = true;
    }

    function parseApps(text) {
        const rows = text.split("\n");
        const out = [];
        for (let i = 0; i < rows.length; ++i) {
            const p = rows[i].split("\t");
            if (p.length < 6 || !p[1] || !p[3])
                continue;

            const icon = (p[2] || "").trim();
            out.push({
                "path": p[0],
                "name": p[1],
                "icon": icon || "application-x-executable",
                "exec": p[3],
                "keywords": p[4] || "",
                "terminal": p[5] === "1"
            });
        }
        out.sort((a, b) => {
            return a.name.localeCompare(b.name, undefined, {
                "sensitivity": "base"
            });
        });
        return out;
    }

    // ============================================================
    // ANILLO: navegación (sobre ringApps)
    // ============================================================
    function navigate(delta) {
        if (root.ringCount === 0)
            return ;

        root.offset = root.mod(root.offset + delta, root.ringCount);
    }

    function jump(delta) {
        if (root.ringCount === 0)
            return ;

        root.offset = root.mod(root.offset + delta, root.ringCount);
    }

    // App del hub (la seleccionada / foco).
    function focusApp() {
        if (root.ringCount === 0)
            return null;

        return root.ringApps[root.mod(root.offset, root.ringCount)];
    }

    // App del diente k (0..N-1); k=0 coincide con el hub.
    function appAt(k) {
        if (root.ringCount === 0)
            return null;

        return root.ringApps[root.mod(root.offset + k, root.ringCount)];
    }

    // Índice (en ringApps) asociado a un diente k.
    function indexAt(k) {
        return root.mod(root.offset + k, root.ringCount);
    }

    // Reorienta el anillo para que la app en el índice `idx` (de `apps`, como
    // lo entrega la búsqueda) quede en el hub.
    function alignToIndex(idx) {
        if (idx < 0 || idx >= root.apps.length)
            return ;

        const rx = root.ringApps.indexOf(root.apps[idx]);
        if (rx < 0)
            return ;

        root.offset = rx;
    }

    // ============================================================
    // LANZAR
    // ============================================================
    function launch(entry) {
        if (!entry)
            return ;

        root.launchError = false;
        if (entry.path && entry.path.length > 0) {
            launchProcess.command = ["gio", "launch", entry.path];
            root.recordUsage(entry.path);
        } else {
            launchProcess.command = ["sh", "-c", entry.exec];
        }
        launchProcess.running = true;
    }

    function launchFocused() {
        root.launch(root.focusApp());
    }

    // Registra el lanzamiento para el orden por uso (fire-and-forget).
    function recordUsage(path) {
        if (!path || path.length === 0)
            return ;

        usageProcess.command = ["bash", root.scriptsDir + "/launcher-usage.sh", "add", path];
        usageProcess.running = true;
    }

    scanProcess: Process {

        stdout: StdioCollector {
            id: scanCollector

            onStreamFinished: {
                root.loading = false;
                const parsed = root.parseApps(scanCollector.text);
                if (parsed.length > 0) {
                    root.apps = parsed;
                    if (root.ringCount > 0)
                        root.offset = root.mod(root.offset, root.ringCount);

                }
                root.loaded = true;
            }
        }

    }

    launchProcess: Process {
        onExited: (exitCode, exitStatus) => {
            root.launchError = exitCode !== 0;
        }
    }

    usageProcess: Process {
        running: false
    }

}
