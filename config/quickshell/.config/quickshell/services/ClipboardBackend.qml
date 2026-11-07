// services/ClipboardBackend.qml
//
// Capa de E/S del portapapeles. Ejecuta `clipboard-ctl` de forma asíncrona y
// emite señales con el resultado. NO conoce colores, listas ni widgets, y no
// toma decisiones de negocio: solo habla con el sistema.
//
// Cola interna: cada Process admite una petición en curso y guarda la última
// pendiente. Así un hover rápido o un refresco durante una operación no
// reinicia procesos a medias ni pierde la petición más reciente.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string ctlPath: Quickshell.env("HOME") + "/.local/bin/clipboard-ctl"

    // ── Señales públicas ────────────────────────────────────────────────
    signal listFinished(string raw)
    signal listFailed(string message)

    signal copyFinished(string id, bool ok)
    signal deleteFinished(string id, bool ok)
    signal wipeFinished(bool ok)

    signal textFinished(string id, string text, bool ok)
    signal thumbFinished(string id, string path, bool ok)
    signal mimeFinished(string id, string mime, bool ok)

    // ════════════════════════════════════════════════════════════════════
    // LIST
    // ════════════════════════════════════════════════════════════════════
    property string _listOut: ""
    property string _listErr: ""
    property bool _listPending: false

    function loadList() {
        if (listProcess.running) {
            root._listPending = true
            return
        }
        root._listOut = ""
        root._listErr = ""
        listProcess.command = [root.ctlPath, "list"]
        listProcess.running = true
    }

    property Process listProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._listOut = text
        }
        stderr: StdioCollector {
            onStreamFinished: root._listErr = text
        }
        onExited: (code, status) => {
            if (code === 0) {
                root.listFinished(root._listOut)
            } else {
                root.listFailed(root._error("cliphist list", code, root._listErr))
            }

            if (root._listPending) {
                root._listPending = false
                Qt.callLater(root.loadList)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // COPY
    // ════════════════════════════════════════════════════════════════════
    property string _copyCurrent: ""
    property string _copyPending: ""

    function copy(id) {
        if (!id) return
        if (copyProcess.running) {
            root._copyPending = id
            return
        }
        root._startCopy(id)
    }

    function _startCopy(id) {
        root._copyCurrent = id
        copyProcess.command = [root.ctlPath, "copy", id]
        copyProcess.running = true
    }

    property Process copyProcess: Process {
        running: false
        stdout: StdioCollector { }
        stderr: StdioCollector { id: copyErr }
        onExited: (code, status) => {
            const id = root._copyCurrent
            root.copyFinished(id, code === 0)
            if (root._copyPending) {
                const next = root._copyPending
                root._copyPending = ""
                Qt.callLater(root._startCopy, next)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // DELETE
    // ════════════════════════════════════════════════════════════════════
    property string _deleteCurrent: ""
    property string _deletePending: ""

    function remove(id) {
        if (!id) return
        if (deleteProcess.running) {
            root._deletePending = id
            return
        }
        root._startDelete(id)
    }

    function _startDelete(id) {
        root._deleteCurrent = id
        deleteProcess.command = [root.ctlPath, "delete", id]
        deleteProcess.running = true
    }

    property Process deleteProcess: Process {
        running: false
        stdout: StdioCollector { }
        stderr: StdioCollector { id: deleteErr }
        onExited: (code, status) => {
            const id = root._deleteCurrent
            root.deleteFinished(id, code === 0)
            if (root._deletePending) {
                const next = root._deletePending
                root._deletePending = ""
                Qt.callLater(root._startDelete, next)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // WIPE
    // ════════════════════════════════════════════════════════════════════
    property bool _wipePending: false

    function wipe() {
        if (wipeProcess.running) {
            root._wipePending = true
            return
        }
        wipeProcess.command = [root.ctlPath, "wipe"]
        wipeProcess.running = true
    }

    property Process wipeProcess: Process {
        running: false
        stdout: StdioCollector { }
        stderr: StdioCollector { id: wipeErr }
        onExited: (code, status) => {
            root.wipeFinished(code === 0)
            if (root._wipePending) {
                root._wipePending = false
                Qt.callLater(root.wipe)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // TEXT (para la vista previa de texto)
    // ════════════════════════════════════════════════════════════════════
    property string _textCurrent: ""
    property string _textOut: ""
    property string _textPending: ""
    property int _textPendingMax: 0

    function loadText(id, maxBytes) {
        if (!id) return
        if (textProcess.running) {
            root._textPending = id
            root._textPendingMax = maxBytes || 0
            return
        }
        root._startText(id, maxBytes || 0)
    }

    function _startText(id, maxBytes) {
        root._textCurrent = id
        const args = [root.ctlPath, "text", id]
        if (maxBytes > 0) args.push(String(maxBytes))
        textProcess.command = args
        textProcess.running = true
    }

    property Process textProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._textOut = text
        }
        stderr: StdioCollector { }
        onExited: (code, status) => {
            root.textFinished(root._textCurrent, root._textOut, code === 0)
            if (root._textPending) {
                const next = root._textPending
                const max = root._textPendingMax
                root._textPending = ""
                root._textPendingMax = 0
                Qt.callLater(root._startText, next, max)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // THUMB (para la vista previa de imagen)
    // ════════════════════════════════════════════════════════════════════
    property string _thumbCurrent: ""
    property string _thumbOut: ""
    property string _thumbPending: ""

    function loadThumb(id) {
        if (!id) return
        if (thumbProcess.running) {
            root._thumbPending = id
            return
        }
        root._startThumb(id)
    }

    function _startThumb(id) {
        root._thumbCurrent = id
        thumbProcess.command = [root.ctlPath, "thumb", id]
        thumbProcess.running = true
    }

    property Process thumbProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._thumbOut = text
        }
        stderr: StdioCollector { }
        onExited: (code, status) => {
            const path = root._thumbOut.replace(/\s+$/, "")
            root.thumbFinished(root._thumbCurrent, code === 0 ? path : "", code === 0)
            if (root._thumbPending) {
                const next = root._thumbPending
                root._thumbPending = ""
                Qt.callLater(root._startThumb, next)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // MIME (metadatos de binarios que cliphist muestra como texto)
    // ════════════════════════════════════════════════════════════════════
    property string _mimeCurrent: ""
    property string _mimeOut: ""
    property string _mimePending: ""

    function loadMime(id) {
        if (!id) return
        if (mimeProcess.running) {
            root._mimePending = id
            return
        }
        root._startMime(id)
    }

    function _startMime(id) {
        root._mimeCurrent = id
        mimeProcess.command = [root.ctlPath, "mime", id]
        mimeProcess.running = true
    }

    property Process mimeProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._mimeOut = text
        }
        stderr: StdioCollector { }
        onExited: (code, status) => {
            const mime = root._mimeOut.replace(/\s+$/, "")
            root.mimeFinished(root._mimeCurrent, code === 0 ? mime : "", code === 0)
            if (root._mimePending) {
                const next = root._mimePending
                root._mimePending = ""
                Qt.callLater(root._startMime, next)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Utilidades
    // ════════════════════════════════════════════════════════════════════
    function _error(label, code, stderrText) {
        const detail = String(stderrText || "").replace(/\s+/g, " ").trim()
        if (detail.length > 0)
            return detail
        return label + " falló (código " + code + ")"
    }
}
