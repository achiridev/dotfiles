// services/BrightnessService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.globals

// Brillo de pantalla (brightnessctl / sysfs) y teclado Acer RGB
// (facer_rgb.py del módulo acer-predator-turbo-and-rgb-keyboard-linux-module).
//
// Escalable:
//   - Pantalla: lectura reactiva por poll de sysfs + escritura con brightnessctl.
//   - Teclado: control vía facer_rgb.py (brillo 0-100, modos, RGB, velocidad, zonas).
//   - Retroiluminaciones extra (clase 'backlight', ej. teclado) se auto-detectan
//     en `extraDevices` y aparecen en el popup sin tocar el widget.
Singleton {
    id: root

    // ============================== PANTALLA ==============================
    readonly property real screenStep: 0.01 // 1% por notch de rueda
    readonly property string screenDevice: AppState.brightnessDevice

    readonly property real screenBrightness: root.screenMax > 0 ? root.screenCurrent / root.screenMax : 0
    readonly property int screenPercent: Math.round(root.screenBrightness * 100)
    readonly property bool screenReady: root.screenMax > 0

    // sysfs no emite eventos inotify (FileView.fileChanged usa QFileSystemWatcher),
    // así que la lectura se enlaza a text() —que sí emite textChanged tras cada
    // re-lectura— y un Timer fuerza reload() periódico. Mismo patrón que AppTheme.
    property FileView maxFile: FileView {
        id: maxFile
        path: Qt.resolvedUrl("file:///sys/class/backlight/" + AppState.brightnessDevice + "/max_brightness")
        blockLoading: false
        watchChanges: true
    }

    property FileView actualFile: FileView {
        id: actualFile
        path: Qt.resolvedUrl("file:///sys/class/backlight/" + AppState.brightnessDevice + "/actual_brightness")
        blockLoading: false
        watchChanges: true
    }

    property int screenMax: parseInt(maxFile.text()) || 0
    property int screenCurrent: parseInt(actualFile.text()) || 0

    // Trigger instantáneo: los binds de hyprland tocan este archivo tras cada
    // brightnessctl (sysfs no emite inotify, así que es el puente para que la
    // barra se entere al momento de Fn+→ / Fn+←). En /tmp inotify sí funciona.
    property FileView triggerFile: FileView {
        path: Qt.resolvedUrl("file:///tmp/qs-brightness-changed")
        blockLoading: true
        watchChanges: true
        onFileChanged: {
            root.maxFile.reload()
            root.actualFile.reload()
        }
    }

    // Poll como red de seguridad para cambios hechos fuera de los binds
    // (ej. slider del popup lo hace por onExited; otras apps caen aquí).
    // 1s basta: la vía rápida es el triggerFile (inotify en /tmp).
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.maxFile.reload()
            root.actualFile.reload()
        }
    }

    // Re-lectura inmediata al terminar la escritura (onExited), además del poll.
    property Process setProcess: Process {
        running: false
        onExited: (code, status) => {
            root.actualFile.reload()
        }
    }

    function setScreen(realValue) {
        if (!root.screenReady) return
        const pct = Math.max(1, Math.min(100, Math.round(realValue * 100)))
        root.setProcess.running = false
        root.setProcess.command = ["brightnessctl", "-d", root.screenDevice, "set", pct + "%"]
        root.setProcess.running = true
    }

    function increaseScreen(step) {
        root.setScreen(root.screenBrightness + (step !== undefined ? step : root.screenStep))
    }

    function decreaseScreen(step) {
        root.setScreen(root.screenBrightness - (step !== undefined ? step : root.screenStep))
    }

    function screenGlyph() {
        if (root.screenPercent < 30) return "󰃞"
        if (root.screenPercent < 70) return "󰃟"
        return "󰃠"
    }

    // ======================= OTROS DISPOSITIVOS ============================
    // Retroiluminaciones adicionales de `brightnessctl -l` (ej. teclados con
    // clase backlight). Cada entry: { name, percent }. Se renderizan en el popup.
    property var extraDevices: []

    function __parseDevices(output) {
        const devices = []
        const re = /Device '([^']+)' of class '([^']+)':/g
        let m
        while ((m = re.exec(output)) !== null) {
            const name = m[1]
            const cls = m[2]
            if (name === root.screenDevice) continue
            if (cls === "backlight") devices.push({ name: name, percent: 0 })
            else if (cls === "leds" && /kbd|keyboard|backlight/i.test(name)) devices.push({ name: name, percent: 0 })
        }
        root.extraDevices = devices
    }

    property Process listProcess: Process {
        id: listProcess
        stdout: StdioCollector {
            id: listCollector
            onStreamFinished: root.__parseDevices(listCollector.text)
        }
    }

    function setExtraDevice(name, percent) {
        const pct = Math.max(0, Math.min(100, Math.round(percent)))
        root.extraDevices = root.extraDevices.map(d => d.name === name ? { name: name, percent: pct } : { name: d.name, percent: d.percent })
        root.setProcess.running = false
        root.setProcess.command = ["brightnessctl", "-d", name, "set", pct + "%"]
        root.setProcess.running = true
    }

    // ====================== TECLADO (Acer RGB) =============================
    readonly property string rgbScript: AppState.keyboardRgbScriptPath
    readonly property bool keyboardAvailable: root.__kbdAvailable

    property bool __kbdAvailable: false

    // Estado local: no hay read-back del módulo, así que el último valor
    // aplicado es la fuente de verdad para los controles del popup.
    property int keyboardBrightness: 100
    property int keyboardMode: 0
    property int keyboardSpeed: 4
    property int keyboardZone: 1
    property int keyboardRed: 120
    property int keyboardGreen: 150
    property int keyboardBlue: 255

    // En modo estático cada zona conserva su propio color (el módulo solo
    // escribe la zona indicada con -z). keyed por índice 0..3 = zonas 1..4.
    property var keyboardZoneColors: [
        { r: 120, g: 150, b: 255 },
        { r: 120, g: 150, b: 255 },
        { r: 120, g: 150, b: 255 },
        { r: 120, g: 150, b: 255 },
    ]

    readonly property var keyboardModeNames: [
        "Estático", "Respiración", "Neón", "Ola", "Shifting", "Zoom"
    ]
    readonly property string keyboardModeName: root.keyboardModeNames[Math.min(root.keyboardMode, root.keyboardModeNames.length - 1)]

    property Process probeProcess: Process {
        id: probeProcess
        onExited: (code, status) => {
            root.__kbdAvailable = code === 0
        }
    }

    property Process keyboardProcess: Process {
        running: false
        onExited: (code, status) => {
            // Solo descarta la entrada que realmente terminó (por si se canceló
            // en marcha y la cola ya fue sustituida por un apply más reciente).
            if (root.__kbdQueue.length > 0 && root.__kbdQueue[0] === root.__lastKbdCommand) {
                root.__kbdQueue.shift()
            }
            if (root.__kbdQueue.length > 0) root.__runKbdCommand()
        }
    }

    property var __kbdQueue: []
    property var __lastKbdCommand: null

    // Debounce: durante un drag continuo del slider se cancela el spawn previo
    // y solo se aplica el último valor.
    Timer {
        id: kbdApplyTimer
        interval: 40
        repeat: false
        onTriggered: {
            root.__kbdQueue = [root.__kbdCommandArgs()]
            root.__runKbdCommand()
        }
    }

    function __kbdCommandArgs(zone) {
        return [
            "python3",
            root.__expand(root.rgbScript),
            "-m", String(root.keyboardMode),
            "-s", String(root.keyboardSpeed),
            "-b", String(root.keyboardBrightness),
            "-z", String(zone !== undefined ? zone : root.keyboardZone),
            "-cR", String(root.keyboardRed),
            "-cG", String(root.keyboardGreen),
            "-cB", String(root.keyboardBlue),
        ]
    }

    function __runKbdCommand() {
        if (!root.keyboardAvailable || root.__kbdQueue.length === 0) return
        root.keyboardProcess.running = false
        root.__lastKbdCommand = root.__kbdQueue[0]
        root.keyboardProcess.command = root.__kbdQueue[0]
        root.keyboardProcess.running = true
    }

    Component.onCompleted: {
        // Detección del device del módulo Acer
        probeProcess.running = false
        probeProcess.command = ["test", "-e", "/dev/acer-gkbbl-0"]
        probeProcess.running = true

        // Auto-detección de retroiluminaciones extra
        listProcess.running = false
        listProcess.command = ["brightnessctl", "-l"]
        listProcess.running = true
    }

    function __expand(str) {
        const home = Quickshell.env("HOME") ?? ""
        return str.replace(/\$HOME/g, home).replace(/^~(?=\/)/, home)
    }

    function applyKeyboard() {
        if (!root.keyboardAvailable) return
        kbdApplyTimer.restart()
    }

    function applyKeyboardAllZones() {
        if (!root.keyboardAvailable) return
        // Aplica el color actual a las 4 zonas de izquierda a derecha.
        const zones = [1, 2, 3, 4].map(z => root.__kbdCommandArgs(z))
        root.__kbdQueue = zones
        root.__runKbdCommand()
    }

    function setKeyboardBrightness(v) {
        root.keyboardBrightness = Math.max(0, Math.min(100, Math.round(v)))
        root.applyKeyboard()
    }

    function increaseKeyboardBrightness(step) {
        root.setKeyboardBrightness(root.keyboardBrightness + (step !== undefined ? step : 1))
    }

    function decreaseKeyboardBrightness(step) {
        root.setKeyboardBrightness(root.keyboardBrightness - (step !== undefined ? step : 1))
    }

    function setKeyboardColor(r, g, b) {
        root.keyboardRed = Math.max(0, Math.min(255, Math.round(r)))
        root.keyboardGreen = Math.max(0, Math.min(255, Math.round(g)))
        root.keyboardBlue = Math.max(0, Math.min(255, Math.round(b)))
        if (root.keyboardMode === 0) {
            // Estático: el color editado pertenece a la zona activa.
            root.__storeActiveZoneColor()
        }
        root.applyKeyboard()
    }

    function __storeActiveZoneColor() {
        const idx = Math.max(0, Math.min(3, root.keyboardZone - 1))
        const colors = root.keyboardZoneColors.map((c, i) =>
            i === idx ? { r: root.keyboardRed, g: root.keyboardGreen, b: root.keyboardBlue } : c)
        root.keyboardZoneColors = colors
    }

    function setKeyboardMode(m) {
        root.keyboardMode = m
        if (m === 0) {
            // Al entrar en estático, el color editado pasa a ser el de la zona activa.
            root.__storeActiveZoneColor()
        }
        root.applyKeyboard()
    }

    function setKeyboardSpeed(s) {
        root.keyboardSpeed = Math.max(0, Math.min(255, Math.round(s)))
        root.applyKeyboard()
    }

    function setKeyboardZone(z) {
        z = Math.max(1, Math.min(4, Math.round(z)))
        if (root.keyboardMode === 0) {
            // Guarda el color editado en la zona que se abandona...
            root.__storeActiveZoneColor()
            // ...y carga el color de la zona seleccionada.
            const c = root.keyboardZoneColors[z - 1]
            root.keyboardRed = c.r
            root.keyboardGreen = c.g
            root.keyboardBlue = c.b
        }
        root.keyboardZone = z
    }

    function keyboardZoneColor(z) {
        const idx = Math.max(0, Math.min(3, z - 1))
        const c = root.keyboardZoneColors[idx]
        return Qt.rgba(c.r / 255, c.g / 255, c.b / 255, 1)
    }
}
