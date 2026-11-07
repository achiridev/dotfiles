// services/ClipboardService.qml
//
// Estado del historial del portapapeles. Es la fuente de verdad para la UI:
// lista parseada, filtro de búsqueda, preview seleccionada y operaciones.
//
// No importa nada de `widgets/`: la capa visual consume estas propiedades y
// llama a estos métodos. El acceso al sistema queda delegado en
// ClipboardBackend y toda la lógica pura en utils/ClipboardUtils.js.
pragma Singleton

import QtQuick
import Quickshell

import qs.services
import "../utils/ClipboardUtils.js" as ClipboardUtils

Singleton {
    id: root

    // ============================================================
    // LÍMITES DE RENDIMIENTO
    // ============================================================
    // Texto máximo que se decodifica para la vista previa (la lista ya trae
    // previews de 1024 caracteres, pero al abrir una entrada se muestra más).
    readonly property int textPreviewMaxBytes: 32768
    // Debounce del hover/selección: evita lanzar un proceso por cada fila
    // que el puntero atraviesa al desplazarse.
    readonly property int previewDebounceMs: 80

    // ============================================================
    // DATOS
    // ============================================================
    property var entries: []        // todas las entradas parseadas
    property var filtered: []       // entradas que pasan la búsqueda
    property string query: ""
    property bool loading: false
    property bool ready: false
    property string error: ""

    readonly property int totalCount: root.entries.length
    readonly property int imageCount: ClipboardUtils.countImages(root.entries)
    readonly property int filteredCount: root.filtered.length

    // ============================================================
    // PREVIEW DE LA ENTRADA SELECCIONADA
    //
    // Se reasigna el objeto completo (no se muta in-place) para que los
    // bindings de QML se actualicen. `image` es una ruta local o "".
    // ============================================================
    property string selectedId: ""
    property var preview: ({
        id: "",
        kind: "",
        text: "",
        image: "",
        mime: "",
        loading: false,
        error: ""
    })

    // ============================================================
    // SEÑALES DE OPERACIÓN (la UI decide si cerrar, notificar, etc.)
    // ============================================================
    signal copied(string id)
    signal removed(string id)
    signal wiped()
    signal refreshed()

    property bool _refreshPending: false
    property string _previewTarget: ""

    // ============================================================
    // CARGA / REFRESCO
    // ============================================================
    function refresh() {
        if (ClipboardBackend.listProcess.running) {
            root._refreshPending = true
            return
        }
        root._refreshPending = false
        root.loading = true
        ClipboardBackend.loadList()
    }

    function _applyList(raw) {
        const parsed = ClipboardUtils.parseList(raw)
        root.entries = parsed
        root.ready = true
        root.loading = false
        root.error = ""
        root._reapplyFilter()
        root.refreshed()

        if (root._refreshPending) {
            root._refreshPending = false
            root.refresh()
        }
    }

    function _reapplyFilter() {
        root.filtered = ClipboardUtils.filterEntries(root.entries, root.query)
    }

    function setQuery(text) {
        const q = (text === undefined || text === null) ? "" : String(text)
        if (q === root.query) return
        root.query = q
        root._reapplyFilter()
    }

    function clearQuery() {
        if (root.query === "") return
        root.query = ""
        root._reapplyFilter()
    }

    // ============================================================
    // SELECCIÓN + PREVIEW
    // ============================================================
    function entryById(id) {
        return ClipboardUtils.findById(root.entries, id)
    }

    function select(id) {
        const next = (id === undefined || id === null) ? "" : String(id)
        if (next === root.selectedId) return
        root.selectedId = next
        root._previewTarget = next

        if (!next) {
            previewDebounce.stop()
            root._clearPreview()
            return
        }

        const entry = root.entryById(next)
        if (!entry) {
            root._clearPreview()
            return
        }

        // Pinta de inmediato el estado "cargando" con los metadatos de la
        // lista, y aplaza la decodificación real para el debounce.
        root.preview = {
            id: next,
            kind: entry.kind,
            text: "",
            image: "",
            mime: "",
            loading: true,
            error: ""
        }
        previewDebounce.restart()
    }

    function _loadPreview(id) {
        if (!id || id !== root.selectedId)
            return
        const entry = root.entryById(id)
        if (!entry) {
            root._clearPreview()
            return
        }

        if (entry.kind === "image") {
            ClipboardBackend.loadThumb(id)
        } else if (entry.kind === "binary") {
            ClipboardBackend.loadMime(id)
        } else {
            ClipboardBackend.loadText(id, root.textPreviewMaxBytes)
        }
    }

    function _clearPreview() {
        root.preview = {
            id: "",
            kind: "",
            text: "",
            image: "",
            mime: "",
            loading: false,
            error: ""
        }
    }

    function clearPreview() {
        previewDebounce.stop()
        root.selectedId = ""
        root._previewTarget = ""
        root._clearPreview()
    }

    function _patchPreview(id, patch) {
        if (root.selectedId !== id) return
        const next = {}
        for (const key in root.preview)
            next[key] = root.preview[key]
        for (const key in patch)
            next[key] = patch[key]
        root.preview = next
    }

    // ============================================================
    // OPERACIONES
    // ============================================================
    function copy(id) {
        if (!id) return
        ClipboardBackend.copy(id)
    }

    function remove(id) {
        if (!id) return
        ClipboardBackend.remove(id)
    }

    function clearAll() {
        ClipboardBackend.wipe()
    }

    // ============================================================
    // TIMERS
    // ============================================================
    Timer {
        id: previewDebounce
        interval: root.previewDebounceMs
        repeat: false
        onTriggered: root._loadPreview(root._previewTarget)
    }

    // Tras copiar, el watcher guarda la entrada y cliphist la mueve al
    // principio (dedupe). Un refresco tardío refleja ese reordenamiento sin
    // bloquear ni competir con el proceso de copia.
    Timer {
        id: copyRefreshTimer
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }

    // ============================================================
    // CONEXIONES CON EL BACKEND
    // ============================================================
    Connections {
        target: ClipboardBackend

        function onListFinished(raw) {
            root._applyList(raw)
        }

        function onListFailed(message) {
            root.loading = false
            root.error = message
            if (root._refreshPending) {
                root._refreshPending = false
                root.refresh()
            }
        }

        function onCopyFinished(id, ok) {
            if (ok) {
                root.error = ""
                root.copied(id)
                copyRefreshTimer.restart()
            } else {
                root.error = "No se pudo restaurar la entrada " + id
            }
        }

        function onDeleteFinished(id, ok) {
            if (!ok) {
                root.error = "No se pudo eliminar la entrada " + id
                return
            }

            const kept = []
            for (let i = 0; i < root.entries.length; ++i) {
                if (root.entries[i].id !== id)
                    kept.push(root.entries[i])
            }
            root.entries = kept
            root._reapplyFilter()
            root.error = ""
            if (root.selectedId === id)
                root.clearPreview()
            root.removed(id)
        }

        function onWipeFinished(ok) {
            if (!ok) {
                root.error = "No se pudo limpiar el historial"
                return
            }
            root.entries = []
            root.filtered = []
            root.clearPreview()
            root.error = ""
            root.ready = true
            root.wiped()
        }

        function onTextFinished(id, text, ok) {
            if (id !== root.selectedId) return
            if (ok)
                root._patchPreview(id, { text: text, loading: false, error: "" })
            else
                root._patchPreview(id, { loading: false, error: "No se pudo leer la entrada" })
        }

        function onThumbFinished(id, path, ok) {
            if (id !== root.selectedId) return
            if (ok && path.length > 0)
                root._patchPreview(id, { image: path, loading: false, error: "" })
            else
                root._patchPreview(id, { image: "", loading: false, error: "Sin vista previa" })
        }

        function onMimeFinished(id, mime, ok) {
            if (id !== root.selectedId) return
            root._patchPreview(id, {
                mime: ok ? mime : "",
                loading: false
            })
        }
    }
}
