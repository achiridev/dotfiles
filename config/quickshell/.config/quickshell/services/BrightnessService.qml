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

    Timer {
        interval: 700
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
        if (root.screenPercent < 30) return "󰃟"
        if (root.screenPercent < 70) return "󰃞"
        return "󰃝"
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

    property Process probeProcess: Process {
        id: probeProcess
        onExited: (code, status) => {
            root.__kbdAvailable = code === 0
        }
    }

    property Process keyboardProcess: Process { running: false }

    // Debounce: durante un drag continuo del slider se cancela el spawn previo
    // y solo se aplica el último valor.
    Timer {
        id: kbdApplyTimer
        interval: 40
        repeat: false
        onTriggered: root.__doApplyKeyboard()
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

    function __doApplyKeyboard() {
        root.keyboardProcess.running = false
        root.keyboardProcess.command = [
            "python3",
            root.__expand(root.rgbScript),
            "-m", String(root.keyboardMode),
            "-s", String(root.keyboardSpeed),
            "-b", String(root.keyboardBrightness),
            "-z", String(root.keyboardZone),
            "-cR", String(root.keyboardRed),
            "-cG", String(root.keyboardGreen),
            "-cB", String(root.keyboardBlue),
        ]
        root.keyboardProcess.running = true
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
        root.applyKeyboard()
    }

    function setKeyboardMode(m) {
        root.keyboardMode = m
        root.applyKeyboard()
    }

    function setKeyboardSpeed(s) {
        root.keyboardSpeed = Math.max(0, Math.min(255, Math.round(s)))
        root.applyKeyboard()
    }

    function setKeyboardZone(z) {
        root.keyboardZone = Math.max(1, Math.min(4, Math.round(z)))
        root.applyKeyboard()
    }
}
