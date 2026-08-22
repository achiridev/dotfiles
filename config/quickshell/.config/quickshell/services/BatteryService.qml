// services/BatteryService.qml
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

import QtQuick
import QtQuick.Layouts
import qs.globals

// ==========================================
// SISTEMA DE BATERÍA
// ==========================================
// Optimización:
//   - Los datos del dispositivo (%, tiempo, potencia) vienen de UPower por
//     señales: cero polling.
//   - El estado de modos (governor/turbo/GPU/servicios) solo se lee mientras
//     el panel está abierto (detailMode): sysfs vía FileView (lecturas de
//     archivo) y envycontrol/systemctl vía procesos cortos con guard para no
//     acumular instancias. En reposo el coste es nulo.
Singleton
{
    id: root
    property var batteryInfo: UPower.displayDevice

    readonly property int percentage: Math.round(batteryInfo.percentage * 100)
    readonly property bool isCharging: batteryInfo.state === UPowerDeviceState.Charging
    readonly property bool isWarning: !isCharging && percentage < 20
    readonly property bool isFull: batteryInfo.state === UPowerDeviceState.FullyCharged || root.percentage >= 100

    readonly property string batteryIcon: {
        if (isCharging) return String.fromCodePoint(0xf0084);
        if (percentage === 100) return String.fromCodePoint(0xf17e2);
        if (percentage > 90) return String.fromCodePoint(0xf0082);
        if (percentage > 80) return String.fromCodePoint(0xf0081);
        if (percentage > 70) return String.fromCodePoint(0xf0080);
        if (percentage > 60) return String.fromCodePoint(0xf007f);
        if (percentage > 50) return String.fromCodePoint(0xf007e);
        if (percentage > 40) return String.fromCodePoint(0xf007d);
        if (percentage > 30) return String.fromCodePoint(0xf007c);
        if (percentage > 20) return String.fromCodePoint(0xf007b);
        return String.fromCodePoint(0xf0083);
    }

    readonly property string colorCharning: "#308b5b"
    readonly property string colorWarning: "#ff5555"
    readonly property string colorDefault: AppTheme.bgModule
    readonly property string color: {
        if (isCharging && percentage < 100 ) return colorCharning
        return colorDefault
    }

    // Color por nivel de carga (panel/barra): semáforo estándar.
    function levelColor(pct) {
        if (pct <= 15) return AppTheme.critical
        if (pct <= 30) return AppTheme.warning
        return AppTheme.success
    }

    // ============================ DATOS DEL PANEL ============================
    readonly property string statusText: {
        switch (batteryInfo.state) {
            case UPowerDeviceState.Charging: return "Cargando"
            case UPowerDeviceState.Discharging: return "Descargando"
            case UPowerDeviceState.FullyCharged: return "Completa"
            case UPowerDeviceState.Empty: return "Vacía"
            case UPowerDeviceState.PendingCharge: return "Preparando carga"
            case UPowerDeviceState.PendingDischarge: return "Preparando descarga"
            default: return "Desconocido"
        }
    }

    // Tiempo restante: UPower entrega segundos (timeToFull al cargar,
    // timeToEmpty al descargar; 0 = desconocido, p.ej. recién conectado).
    readonly property int secondsRemaining: root.isCharging ? batteryInfo.timeToFull : batteryInfo.timeToEmpty

    readonly property string timeRemainingText: {
        if (root.isFull) return "Completa"
        if (root.secondsRemaining <= 0) return "—"
        return root.formatDuration(root.secondsRemaining)
    }

    function formatDuration(totalSeconds) {
        let h = Math.floor(totalSeconds / 3600)
        let m = Math.round((totalSeconds % 3600) / 60)
        if (m === 60) { h += 1; m = 0 }
        if (h <= 0) return Math.max(m, 1) + "m"
        return m > 0 ? h + "h " + m + "m" : h + "h"
    }

    // UPower reporta la tasa siempre positiva; el sentido lo da el estado.
    readonly property real powerWatts: batteryInfo.changeRate || 0
    readonly property real energyWh: batteryInfo.energy || 0
    readonly property real energyCapacityWh: batteryInfo.energyCapacity || 0
    readonly property bool healthSupported: batteryInfo.healthSupported
    readonly property int healthPercent: Math.round(batteryInfo.healthPercentage || 0)

    function formatPower() {
        return (root.isCharging ? "+" : "-") + Math.abs(root.powerWatts).toFixed(1) + " W"
    }

    function formatEnergy() {
        return root.energyWh.toFixed(1) + " / " + root.energyCapacityWh.toFixed(1) + " Wh"
    }

    // =================== MODOS DE ENERGÍA (battery-mode) =====================
    // Modo activo inferido del estado REAL del sistema (no hay forma de
    // preguntarle al script sin disparar su sudo):
    //   gaming -> GPU nvidia + governor performance
    //   high   -> GPU integrada (la NVIDIA quedó fuera tras reboot)
    //   low    -> powersave + turbo desactivado
    //   off    -> cualquier otra combinación (modo normal)
    readonly property string activeMode: {
        if (root.gpuMode === "nvidia" && root.governor === "performance") return "gaming"
        if (root.gpuMode === "integrated") return "high"
        if (root.governor === "powersave" && !root.turboEnabled) return "low"
        return "off"
    }

    property string gpuMode: ""          // hybrid | integrated | nvidia | ""
    property bool tlpActive: false
    property bool cpufreqActive: false

    // no_turbo=1 significa turbo OFF; archivo ilegible se asume turbo ON.
    readonly property string governor: governorFile.text().trim()
    readonly property bool turboEnabled: turboFile.text().trim() !== "1"

    property FileView governorFile: FileView {
        path: Qt.resolvedUrl("file:///sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
        blockLoading: false
        watchChanges: false
    }

    property FileView turboFile: FileView {
        path: Qt.resolvedUrl("file:///sys/devices/system/cpu/intel_pstate/no_turbo")
        blockLoading: false
        watchChanges: false
    }

    // ======================== POLLING BAJO DEMANDA ===========================
    // Lo activa el widget cuando su panel está visible.
    property bool detailMode: false

    onDetailModeChanged: {
        if (root.detailMode) {
            root.__poll()
            pollTimer.restart()
        } else {
            pollTimer.stop()
        }
    }

    Timer {
        id: pollTimer
        interval: 4000
        repeat: true
        running: false
        onTriggered: root.__poll()
    }

    function __poll() {
        governorFile.reload()
        turboFile.reload()
        if (!statusProcess.running) statusProcess.running = true
        if (!gpuProcess.running) gpuProcess.running = true
    }

    // TLP + auto-cpufreq en UNA sola llamada a systemctl.
    property Process statusProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.tlpActive = lines[0] === "active"
                root.cpufreqActive = lines[1] === "active"
            }
        }
    }

    property Process gpuProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.gpuMode = text.trim().toLowerCase()
        }
    }

    // Cambia de modo vía kitty flotante (regla hypr "qs-battery-mode"): el
    // sudo del script pide contraseña en esa terminal. Si el script falla, el
    // wrapper espera una tecla para poder leer el error; si termina bien, la
    // ventana se cierra sola (el aviso llega por notify-send).
    function applyMode(mode) {
        const flags = { off: "--off", low: "--low", high: "--high", gaming: "--gaming" }
        if (!(mode in flags) || modeProcess.running) return
        const script = Quickshell.env("HOME") + "/.local/bin/battery-mode"
        modeProcess.command = [
            "kitty",
            "--class", "qs-battery-mode",
            "--title", "qs-battery-mode",
            "-e", "bash", "-c",
            script + " " + flags[mode]
                + "; code=$?; [ $code -ne 0 ] && { echo; read -n1 -sr -p \"Falló (código $code) — pulsa una tecla para cerrar\"; }; exit $code"
        ]
        modeProcess.running = true
    }

    property Process modeProcess: Process {
        running: false
        onRunningChanged: {
            // Al cerrar la terminal, refresca el estado si el panel sigue abierto.
            if (!running && root.detailMode) root.__poll()
        }
    }
}
