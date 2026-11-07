// globals/ClipboardState.qml
//
// Estado de INTERACCIÓN del gestor de portapapeles: ventana abierta, consulta
// de búsqueda, índice seleccionado y confirmación de limpieza.
//
// No ejecuta procesos ni conoce colores/widgets. La ventana y los componentes
// visuales leen estas propiedades y llaman a estos métodos; los datos y las
// operaciones viven en ClipboardService.
pragma Singleton

import QtQuick
import Quickshell

import qs.services

Singleton {
    id: root

    // ============================================================
    // VENTANA
    // ============================================================
    property bool open: false

    // ============================================================
    // SELECCIÓN
    // ============================================================
    property int selectedIndex: 0
    readonly property int pageSize: 8

    readonly property var currentEntry: {
        const list = ClipboardService.filtered
        if (root.selectedIndex < 0 || root.selectedIndex >= list.length)
            return null
        return list[root.selectedIndex]
    }
    readonly property string currentId: root.currentEntry ? root.currentEntry.id : ""

    // ============================================================
    // CONFIRMACIÓN DE LIMPIEZA (dos pasos, 3 s)
    // ============================================================
    property bool confirmClear: false

    // Id cuya copia está en curso y debe cerrar el panel al terminar.
    property string _pendingCloseId: ""

    // ============================================================
    // APERTURA / CIERRE
    // ============================================================
    function toggle() {
        if (root.open) root.close()
        else root.openWindow()
    }

    function openWindow() {
        root.confirmClear = false
        confirmTimer.stop()
        root._pendingCloseId = ""
        root.open = true
        root.selectedIndex = 0
        pendingCloseTimer.stop()
        ClipboardService.clearQuery()
        ClipboardService.refresh()
        root._syncSelection()
    }

    function close() {
        if (!root.open) return
        root.open = false
        root.confirmClear = false
        confirmTimer.stop()
        root._pendingCloseId = ""
        pendingCloseTimer.stop()
        ClipboardService.clearPreview()
    }

    // ============================================================
    // BÚSQUEDA
    // ============================================================
    function setQuery(text) {
        ClipboardService.setQuery(text)
        root.selectedIndex = 0
        if (root.open) root._syncSelection()
    }

    function clearQuery() {
        if (ClipboardService.query === "") return
        ClipboardService.clearQuery()
        root.selectedIndex = 0
        if (root.open) root._syncSelection()
    }

    // ============================================================
    // NAVEGACIÓN
    // ============================================================
    function selectIndex(index) {
        const list = ClipboardService.filtered
        if (list.length === 0) {
            root.selectedIndex = 0
            ClipboardService.clearPreview()
            return
        }
        let idx = index
        if (idx < 0) idx = 0
        if (idx >= list.length) idx = list.length - 1
        root.selectedIndex = idx
        ClipboardService.select(list[idx].id)
    }

    function move(delta) {
        const list = ClipboardService.filtered
        if (list.length === 0) return
        // Navegación circular: desde la primera flecha arriba va a la última.
        let idx = (root.selectedIndex + delta) % list.length
        if (idx < 0) idx += list.length
        root.selectIndex(idx)
    }

    function movePage(delta) {
        root.move(delta * root.pageSize)
    }

    function selectFirst() { root.selectIndex(0) }
    function selectLast() { root.selectIndex(ClipboardService.filtered.length - 1) }

    function hover(id) {
        const list = ClipboardService.filtered
        for (let i = 0; i < list.length; ++i) {
            if (list[i].id === id) {
                root.selectIndex(i)
                return
            }
        }
    }

    // ============================================================
    // ACCIONES
    // ============================================================
    function activate(id) {
        const target = id || root.currentId
        if (!target) return
        root._pendingCloseId = target
        pendingCloseTimer.restart()
        ClipboardService.copy(target)
    }

    function activateCurrent() {
        root.activate(root.currentId)
    }

    function deleteCurrent() {
        const entry = root.currentEntry
        if (!entry) return
        ClipboardService.remove(entry.id)
    }

    // Primer clic: pide confirmación. Segundo clic dentro de 3 s: limpia.
    function requestClear() {
        if (!root.confirmClear) {
            root.confirmClear = true
            confirmTimer.restart()
            return
        }
        root.confirmClear = false
        confirmTimer.stop()
        ClipboardService.clearAll()
    }

    // ============================================================
    // SINCRONIZACIÓN CON LA LISTA FILTRADA
    // ============================================================
    function _syncSelection() {
        const list = ClipboardService.filtered
        if (list.length === 0) {
            root.selectedIndex = 0
            ClipboardService.clearPreview()
            return
        }
        if (root.selectedIndex >= list.length)
            root.selectedIndex = list.length - 1
        if (root.selectedIndex < 0)
            root.selectedIndex = 0
        ClipboardService.select(list[root.selectedIndex].id)
    }

    Timer {
        id: confirmTimer
        interval: 3000
        repeat: false
        onTriggered: root.confirmClear = false
    }

    Timer {
        id: pendingCloseTimer
        interval: 2500
        repeat: false
        onTriggered: root._pendingCloseId = ""
    }

    Connections {
        target: ClipboardService

        function onFilteredChanged() {
            if (root.open) root._syncSelection()
        }

        function onRefreshed() {
            if (root.open) root._syncSelection()
        }

        function onWiped() {
            root.selectedIndex = 0
            root._syncSelection()
        }

        function onCopied(id) {
            if (root._pendingCloseId !== id) return
            root._pendingCloseId = ""
            pendingCloseTimer.stop()
            root.close()
        }
    }
}
