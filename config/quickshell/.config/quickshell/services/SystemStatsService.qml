// services/SystemStatsService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.globals

// ==========================================
// ESTADÍSTICAS DEL SISTEMA (CPU / GPU / RAM)
// ==========================================
// Fuentes de datos:
//   - Uso CPU:  /proc/stat (delta entre lecturas; sin procesos externos)
//   - Temps:    /sys/class/hwmon/* (CPU, laptop y NVMe autodetectados UNA vez)
//   - RAM:      /proc/meminfo
//   - GPU:      nvidia-smi (una única query con TODAS las métricas)
//
// Optimización (el clásico problema de "nvidia-smi despierta la GPU"):
//   - La barra solo muestra CPU/RAM (lecturas de archivo, coste ~0).
//   - nvidia-smi SOLO corre con el popup abierto (detailMode): en reposo este
//     servicio no genera ningún despertar de GPU.
//   - Guard de solapamiento: si la query anterior sigue viva se salta el tick,
//     así los procesos nunca se acumulan aunque la GPU tarde en responder.
//   - Polling adaptativo: 3s en reposo, 1s mientras el popup está abierto.
Singleton {
    id: root

    // ============================== CPU ==============================
    // Fracción 0..1 interna; expuesta como % redondeado. QML no emite señal
    // de cambio al asignar el mismo valor, así que el gating de re-renders
    // es automático.
    property real __cpuUsageFrac: 0
    readonly property int cpuUsage: Math.round(root.__cpuUsageFrac * 100)

    readonly property bool hasCpuTemp: root.__cpuTempPath !== ""
    readonly property int cpuTemp: root.__readTemp(cpuTempFile)

    // ============================== GPU ==============================
    property bool gpuAvailable: false
    property string gpuName: ""
    property int gpuUsage: 0
    property int gpuTemp: 0
    property real vramUsedGb: 0
    property real vramTotalGb: 0
    readonly property real vramPercent: root.vramTotalGb > 0 ? (root.vramUsedGb / root.vramTotalGb) * 100 : 0

    // ============================ MEMORIA ============================
    readonly property var __mem: {
        const map = { total: 0, available: 0, cached: 0, sreclaimable: 0 }
        const lines = memFile.text().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(\w+):\s+(\d+) kB$/)
            if (!m) continue
            switch (m[1]) {
                case "MemTotal":     map.total = Number(m[2]); break
                case "MemAvailable": map.available = Number(m[2]); break
                case "Cached":       map.cached = Number(m[2]); break
                case "SReclaimable": map.sreclaimable = Number(m[2]); break
            }
        }
        return map
    }

    readonly property real memTotalGb: root.__mem.total / 1048576
    readonly property real memUsedGb: (root.__mem.total - root.__mem.available) / 1048576
    readonly property real memFreeGb: root.__mem.available / 1048576
    readonly property real memCachedGb: (root.__mem.cached + root.__mem.sreclaimable) / 1048576
    readonly property real memPercent: root.memTotalGb > 0 ? (root.memUsedGb / root.memTotalGb) * 100 : 0
    readonly property int memUsage: Math.round(root.memPercent)

    // ===================== TEMPS EXTRA (/sys) ========================
    readonly property bool hasLaptopTemp: root.__laptopTempPath !== ""
    readonly property int laptopTemp: root.__readTemp(laptopTempFile)
    readonly property bool hasNvmeTemp: root.__nvmeTempPath !== ""
    readonly property int nvmeTemp: root.__readTemp(nvmeTempFile)

    function __readTemp(file) {
        const v = parseInt(file.text())
        return isNaN(v) ? 0 : Math.round(v / 1000)
    }

    // ======================== UMBRALES / COLOR =======================
    readonly property int tempWarnAt: 60
    readonly property int tempCritAt: 80 // critical-threshold de waybar

    function statusColor(t) {
        if (t >= root.tempCritAt) return AppTheme.critical
        if (t >= root.tempWarnAt) return AppTheme.warning
        return AppTheme.accent
    }

    function usageColor(pct) {
        if (pct >= 90) return AppTheme.critical
        if (pct >= 80) return AppTheme.warning
        return AppTheme.accent
    }

    // ======================= POLLING ADAPTATIVO ======================
    // detailMode lo activa el widget cuando su popup está abierto.
    property bool detailMode: false

    onDetailModeChanged: {
        // Dato fresco al instante + aplica la nueva cadencia ya.
        root.__poll()
        pollTimer.restart()
    }

    Timer {
        id: pollTimer
        interval: root.detailMode ? 1000 : 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.__poll()
    }

    function __poll() {
        statFile.reload()
        memFile.reload()
        if (root.hasCpuTemp) cpuTempFile.reload()
        if (root.hasLaptopTemp) laptopTempFile.reload()
        if (root.hasNvmeTemp) nvmeTempFile.reload()
        // GPU solo se consulta cuando el popup la necesita.
        if (root.detailMode) root.__pollGpu()
    }

    // =========================== /proc/stat ==========================
    property FileView statFile: FileView {
        path: Qt.resolvedUrl("file:///proc/stat")
        blockLoading: false
        watchChanges: false // procfs no emite inotify; el Timer fuerza reload()
    }

    // Muestra actual de contadores. Se re-evalúa tras cada reload() porque
    // text() emite textChanged (mismo patrón que BrightnessService).
    readonly property var __cpuSample: {
        const first = statFile.text().split("\n")[0]
        if (!first || !first.startsWith("cpu ")) return null
        const parts = first.trim().split(/\s+/).slice(1).map(Number)
        return parts.length >= 5 ? parts : null
    }

    property var __prevSample: null

    on__CpuSampleChanged: {
        const cur = root.__cpuSample
        const prev = root.__prevSample
        if (!cur) return
        if (prev) {
            const idleOf = c => c[3] + c[4] // idle + iowait
            const totalOf = c => c.reduce((a, b) => a + b, 0)
            const dTotal = totalOf(cur) - totalOf(prev)
            const dIdle = idleOf(cur) - idleOf(prev)
            if (dTotal > 0)
                root.__cpuUsageFrac = Math.max(0, Math.min(1, 1 - dIdle / dTotal))
        }
        root.__prevSample = cur
    }

    // ========================== /proc/meminfo ========================
    property FileView memFile: FileView {
        path: Qt.resolvedUrl("file:///proc/meminfo")
        blockLoading: false
        watchChanges: false
    }

    // ========================= TEMPS (/sys) ==========================
    // Los índices hwmonN cambian entre kernels/boots: resolvemos las 3 rutas
    // UNA vez clasificando por nombre de sensor.
    property string __cpuTempPath: ""
    property string __laptopTempPath: ""
    property string __nvmeTempPath: ""

    on__CpuTempPathChanged: {
        if (root.__cpuTempPath !== "")
            cpuTempFile.path = Qt.resolvedUrl("file://" + root.__cpuTempPath)
    }

    on__LaptopTempPathChanged: {
        if (root.__laptopTempPath !== "")
            laptopTempFile.path = Qt.resolvedUrl("file://" + root.__laptopTempPath)
    }

    on__NvmeTempPathChanged: {
        if (root.__nvmeTempPath !== "")
            nvmeTempFile.path = Qt.resolvedUrl("file://" + root.__nvmeTempPath)
    }

    property FileView cpuTempFile: FileView { blockLoading: false; watchChanges: false }
    property FileView laptopTempFile: FileView { blockLoading: false; watchChanges: false }
    property FileView nvmeTempFile: FileView { blockLoading: false; watchChanges: false }

    property Process probeProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // Una línea: "<cpu> <laptop> <nvme>" (vacíos si no existen).
                const parts = text.trim().split(/\s+/)
                root.__cpuTempPath = parts[0] ?? ""
                root.__laptopTempPath = parts[1] ?? ""
                root.__nvmeTempPath = parts[2] ?? ""
            }
        }
    }

    // ======================= GPU (nvidia-smi) ========================
    property Process gpuProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.__parseGpu(text)
        }
    }

    function __pollGpu() {
        if (gpuProcess.running) return // guard: nunca acumular queries
        gpuProcess.command = [
            "nvidia-smi",
            "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits"
        ]
        gpuProcess.running = true
    }

    function __parseGpu(out) {
        const line = out.split("\n")[0]?.trim() ?? ""
        const p = line.split(",").map(s => s.trim())
        if (p.length < 5 || p[1] === "" || p[4] === "" || isNaN(Number(p[1]))) {
            root.gpuAvailable = false
            return
        }
        root.gpuName = p[0]
        root.gpuUsage = Number(p[1])
        root.gpuTemp = Number(p[2])
        root.vramUsedGb = Number(p[3]) / 1024 // MiB -> GiB
        root.vramTotalGb = Number(p[4]) / 1024
        root.gpuAvailable = true
    }

    Component.onCompleted: {
        probeProcess.command = ["sh", "-c", 'cpu=""; lap=""; ssd=""; for d in /sys/class/hwmon/hwmon*; do n=$(cat "$d/name" 2>/dev/null); case "$n" in coretemp|k10temp|zenpower|cpu_thermal) [ -z "$cpu" ] && cpu="$d/temp1_input";; acpitz*) [ -z "$lap" ] && lap="$d/temp1_input";; nvme) [ -z "$ssd" ] && ssd="$d/temp1_input";; esac; done; echo "$cpu $lap $ssd"']
        probeProcess.running = true
    }
}
