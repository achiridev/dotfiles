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
    // UPower.displayDevice es el dispositivo COMPUESTO (línea + batería): tiene
    // el % y el estado, pero su salud siempre vale 0/no-soportada. La celda real
    // (BAT1) está en UPower.devices y sí trae healthPercentage (aquí, 46,6 %).
    readonly property var cellInfo: {
        const all = UPower.devices.values
        if (!all) return null
        for (let i = 0; i < all.length; i++) {
            const d = all[i]
            if (d && d.type === UPowerDeviceType.Battery) return d
        }
        return null
    }

    readonly property bool healthSupported: {
        const c = root.cellInfo
        if (c) return c.healthSupported
        return batteryInfo.healthSupported
    }

    readonly property int healthPercent: {
        const c = root.cellInfo
        const v = c ? c.healthPercentage : batteryInfo.healthPercentage
        return Math.round(v || 0)
    }

    // Fuente de alimentación actual: UPower expone `onBattery` en el objeto
    // raíz del servicio (no en el dispositivo).
    readonly property bool onBattery: UPower.onBattery
    readonly property string powerSource: root.onBattery ? "Batería" : "Corriente"

    // Identificación de la celda (datos estáticos: solo se leen una vez).
    // El ?? "" evita el "Unable to assign undefined to QString" del arranque,
    // antes de que llegue el primer poll de sysfs.
    readonly property string vendor: root.__sys.vendor ?? ""
    readonly property string modelName: root.__sys.model ?? ""

    function formatPower() {
        return (root.isCharging ? "+" : "-") + Math.abs(root.powerWatts).toFixed(1) + " W"
    }

    function formatEnergy() {
        return root.energyWh.toFixed(1) + " / " + root.energyCapacityWh.toFixed(1) + " Wh"
    }

    // Color de la salud de la celda. Por debajo del 80 % la batería ya está
    // degradada de forma apreciable; por debajo del 50 % es aging severo.
    function healthColor(pct) {
        if (pct <= 0) return AppTheme.color8
        if (pct < 50) return AppTheme.critical
        if (pct < 80) return AppTheme.warning
        return AppTheme.success
    }

    // ====================== LECTURAS EXTRA DE sysfs =========================
    // Se agrupan en UNA sola llamada a `sh` por poll (en vez de un FileView por
    // archivo): algunos ficheros de power_supply vienen vacíos o con
    // "infinite", así que un único parseo por clave es más robusto.
    property var __sys: ({})

    function __num(sysfs, key) {
        const v = sysfs[key]
        if (v === undefined || v === "" || v === "infinite" || v === "unknown") return 0
        const n = Number(v)
        return isNaN(n) ? 0 : n
    }

    // Tensión actual de la celda (µV en sysfs → V).
    readonly property real voltageVolts: root.__num(root.__sys, "volts") / 1e6
    // Capacidad real (charge_full) y de diseño (charge_full_design).
    // sysfs las da en µAh; aquí se pasan a mAh para que los números sean
    // legibles (1739000 µAh -> 1739 mAh).
    readonly property real chargeFullMah: root.__num(root.__sys, "mah") / 1000
    readonly property real chargeDesignMah: root.__num(root.__sys, "mah_design") / 1000
    // EnergíaWh de diseño = Ah de diseño * tensión mínima de diseño (V).
    // Coincide con el `energy-full-design` que reporta UPower (57,49 Wh).
    readonly property real energyDesignWh:
        (root.chargeDesignMah / 1000) * (root.__num(root.__sys, "v_min") / 1e6)
    readonly property bool hasBatteryDetail: root.voltageVolts > 0

    // Ciclos de carga. OJO: en este portátil el kernel informa 0 y UPower
    // `ChargeCycles = -1`; se expone pero no se muestra por ser poco fiable.
    readonly property int cycleCount: root.__num(root.__sys, "cycles")

    

    function __parseSys(text) {
        const out = {}
        const lines = text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const eq = lines[i].indexOf("=")
            if (eq <= 0) continue
            out[lines[i].slice(0, eq)] = lines[i].slice(eq + 1).trim()
        }
        root.__sys = out
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

    // gpuMode es el modo REAL en uso; gpuTarget es el modo CONFIGURADO para el
    // próximo arranque. envycontrol escribe la configuración al cambiar y su
    // `--query` la lee, así que tras pedir "integrated" --query ya devuelve
    // "integrated" aunque la NVIDIA siga cargada en el kernel.
    property string gpuMode: ""          // hybrid | integrated | nvidia | ""
    property string gpuTarget: ""        // id. + pendiente de aplicar
    property bool tlpActive: false
    property bool cpufreqActive: false
    property bool nvidiaModuleLoaded: false

    // Reinicio pendiente cuando el modo configurado no coincide con el que el
    // kernel tiene realmente cargado:
    //   integrado pedido + nvidia cargada  -> falta apagar la NVIDIA
    //   nvidia pedida + nvidia no cargada  -> falta activar la NVIDIA
    readonly property bool gpuRebootPending: {
        if (root.gpuTarget === "" || root.gpuMode === "") return false
        if (root.gpuTarget === "integrated") return root.nvidiaModuleLoaded
        // hybrid y nvidia ambos requieren la NVIDIA presente en el kernel.
        return !root.nvidiaModuleLoaded
    }

    readonly property string gpuTargetName: {
        if (root.gpuTarget === "integrated") return "iGPU"
        if (root.gpuTarget === "nvidia") return "GPU dedicada"
        if (root.gpuTarget === "hybrid") return "GPU híbrida"
        return "—"
    }

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
        if (!sysReader.running) sysReader.running = true
        if (!gpuProcess.running) gpuProcess.running = true
    }

    // ------------------ SYSFS: batería + modo real de GPU --------------------
    // Todo en UNA sola llamada a `sh`. El script es una CONSTANTE (no interpola
    // datos: solo lee rutas fijas), así que la propiedad __sysCmd no cambia y
    // el `command` del Process se puede enlazar sin reasignarlo en cada poll.
    //
    // El modo de GPU REAL se deduce del kernel porque `envycontrol --query`
    // solo devuelve el modo CONFIGURADO, que cambia al instante al aplicar un
    // modo (antes incluso del reinicio) y por eso no dice qué se está usando:
    //   - módulo nvidia ausente        -> integrated
    //   - nvidia presente + boot_vga=0 -> hybrid (la iGPU lleva la pantalla)
    //   - nvidia presente + boot_vga=1 -> nvidia (la NVIDIA lleva la pantalla)
    // En modo híbrido el kernel marca la iGPU como boot_vga; en modo nvidia la
    // marca la NVIDIA.
    readonly property string __sysCmd:
        "p=/sys/class/power_supply/BAT1; "
        + "echo model=$(cat $p/model_name 2>/dev/null); "
        + "echo vendor=$(cat $p/manufacturer 2>/dev/null); "
        + "echo volts=$(cat $p/voltage_now 2>/dev/null); "
        + "echo mah=$(cat $p/charge_full 2>/dev/null); "
        + "echo mah_design=$(cat $p/charge_full_design 2>/dev/null); "
        + "echo v_min=$(cat $p/voltage_min_design 2>/dev/null); "
        + "echo cycles=$(cat $p/cycle_count 2>/dev/null); "
        + "if [ -d /sys/module/nvidia ]; then echo nvidia=1; else echo nvidia=0; fi; "
        + "for c in /sys/class/drm/card[0-9]*; do "
        + 'if [ -e "$c/device/boot_vga" ] && [ -L "$c/device/driver" ] '
        + '&& [ "$(basename "$(readlink -f "$c/device/driver")")" = nvidia ]; then '
        + 'echo nvboot=$(cat "$c/device/boot_vga"); fi; '
        + "done"

    property Process sysReader: Process {
        running: false
        command: ["sh", "-c", root.__sysCmd]
        stdout: StdioCollector {
            onStreamFinished: {
                root.__parseSys(text)
                root.nvidiaModuleLoaded = root.__sys.nvidia === "1"
                if (!root.nvidiaModuleLoaded) {
                    root.gpuMode = "integrated"
                } else {
                    root.gpuMode = root.__sys.nvboot === "1" ? "nvidia" : "hybrid"
                }
            }
        }
    }

    // TLP + auto-cpufreq: dos líneas de una sola llamada a systemctl.
    property Process statusProcess: Process {
        running: false
        command: ["sh", "-c", "systemctl is-active tlp; systemctl is-active auto-cpufreq"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.tlpActive = lines[0] === "active"
                root.cpufreqActive = lines[1] === "active"
            }
        }
    }

    // `envycontrol --query` devuelve el modo CONFIGURADO: sirve para saber si hay
    // un cambio pendiente de aplicar tras reiniciar, NO para saber qué GPU se
    // está usando (eso lo deduce sysReader del kernel).
    property Process gpuProcess: Process {
        running: false
        command: ["envycontrol", "--query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().toLowerCase()
                if (m === "integrated" || m === "hybrid" || m === "nvidia")
                    root.gpuTarget = m
            }
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
