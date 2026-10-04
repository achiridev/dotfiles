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

    // ===================== Frecuencias / EPP del CPU =====================
    // intel_pstate: el EPP es lo que realmente decide el consumo entre
    // governor y boost. Se leen de cpufreq/policy0 (equivalente a cpu0 en esta
    // plataforma, pero más robusto: vale también con CPUs sin cpu0cpufreq).
    readonly property string epp: eppFile.text().trim()
    readonly property string eppAvailable: eppListFile.text().trim()
    readonly property bool hasEpp: root.epp !== "" && root.epp !== "unknown"

    // Frecuencias en MHz (sysfs las da en kHz).
    readonly property real cpuFreqMhz: root.__readKhz(freqFile)
    readonly property real cpuMinMhz: root.__readKhz(minFreqFile)
    readonly property real cpuMaxMhz: root.__readKhz(maxFreqFile)
    readonly property real cpuFreqPercent:
        root.cpuMaxMhz > 0 ? Math.min(100, (root.cpuFreqMhz / root.cpuMaxMhz) * 100) : 0

    // Nombres legibles de los modos de EPP.
    function eppLabel(v) {
        switch (v) {
            case "performance": return "rendimiento"
            case "balance_performance": return "balanceado+"
            case "balance_power": return "ahorro"
            case "power": return "máx. ahorro"
            default: return v !== "" ? v : "—"
        }
    }

    function __readKhz(file) {
        const v = Number(file.text().trim())
        return isNaN(v) || v <= 0 ? 0 : Math.round(v / 1000)
    }

    // ============================ NÚCLEOS ===============================
    // Array de {label, temp} con TODOS los sensores de coretemp, no solo el
    // Package: incluye los núcleos lógicos con SMT. Se rellena al sondear
    // (detailMode), así que en reposo no hay proceso extra.
    property var coreTemps: []
    readonly property int coreTempMax:
        coreTemps.reduce((m, c) => Math.max(m, c.temp), 0)

    // ============================== GPU ==============================
    property bool gpuAvailable: false
    property string gpuName: ""
    property string gpuDriver: ""
    property string gpuPstate: ""
    property int gpuUsage: 0
    property int gpuTemp: 0
    property int gpuCoreClockMhz: 0
    property int gpuMemClockMhz: 0
    property real gpuPowerW: 0
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

    // El NVMe expone un segundo sensor ("Sensor 1"), más cercano al controlador
    // que el "Composite". Si no existe, se oculta.
    readonly property bool hasNvmeTemp2: root.__nvmeTemp2Path !== ""
    readonly property int nvmeTemp2: root.__readTemp(nvmeTemp2File)

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

    // Color base por métrica: cada una toma un tono distinto de la paleta
    // wallust; warning/critical pisan al superar los umbrales.
    function cpuColor(t) {
        if (t >= root.tempCritAt) return AppTheme.critical
        if (t >= root.tempWarnAt) return AppTheme.warning
        return AppTheme.color4 // azul
    }

    function gpuColor(t) {
        if (t >= root.tempCritAt) return AppTheme.critical
        if (t >= root.tempWarnAt) return AppTheme.warning
        return AppTheme.color13 // magenta
    }

    function memColor(pct) {
        if (pct >= 90) return AppTheme.critical
        if (pct >= 80) return AppTheme.warning
        return AppTheme.color2 // verde
    }

    // ======================= POLLING ADAPTATIVO ======================
    // detailMode lo activa el widget cuando su popup está abierto.
    property bool detailMode: false

    // detailStatsRequest permite a otro consumidor (el Panel de Control) pedir
    // los datos EXPENSOS (nvidia-smi + sondeo de núcleos) sin tocar el modo de
    // polling del popup, para no subir su refresco a 1 Hz.
    property bool detailStatsRequest: false
    readonly property bool detailed: root.detailMode || root.detailStatsRequest

    onDetailModeChanged: {
        // Dato fresco al instante + aplica la nueva cadencia ya.
        root.__poll()
        pollTimer.restart()
    }

    onDetailStatsRequestChanged: root.__poll()

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
        if (root.hasNvmeTemp2) nvmeTemp2File.reload()
        // Frecuencias y EPP: lecturas de archivo baratas, siempre activas.
        freqFile.reload()
        minFreqFile.reload()
        maxFreqFile.reload()
        eppFile.reload()
        // Sondeo de núcleos (un `cat` por sensor) y nvidia-smi solo cuando
        // alguien los está mirando.
        if (root.detailed) {
            root.__pollCoreTemps()
            root.__pollGpu()
        }
    }

    // ================= FRECUENCIAS / EPP (cpufreq policy0) ==================
    // Rutas fijas: policy0 existe en cualquier plataforma con intel_pstate y no
    // cambia entre boots (a diferencia de los índices hwmonN).
    property FileView freqFile: FileView {
        path: Qt.resolvedUrl("file:///sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq")
        blockLoading: false
        watchChanges: false
    }

    property FileView minFreqFile: FileView {
        path: Qt.resolvedUrl("file:///sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq")
        blockLoading: false
        watchChanges: false
    }

    property FileView maxFreqFile: FileView {
        path: Qt.resolvedUrl("file:///sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq")
        blockLoading: false
        watchChanges: false
    }

    property FileView eppFile: FileView {
        path: Qt.resolvedUrl("file:///sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference")
        blockLoading: false
        watchChanges: false
    }

    property FileView eppListFile: FileView {
        path: Qt.resolvedUrl("file:///sys/devices/system/cpu/cpufreq/policy0/energy_performance_available_preferences")
        blockLoading: false
        watchChanges: false
    }

    // ======================== NÚCLEOS (coretemp) ============================
    // Un único `sh` lee TODOS los sensores de una vez. Cada registro lleva tres
    // campos separados por `|`:
    //     <índice>|<milikelvinios>|<etiqueta>
    // El pipe hace de separador porque las etiquetas de coretemp contienen
    // espacios ("Package id 0", "Core 12") y no valen como "clave=valor".
    function __pollCoreTemps() {
        if (coreProbe.running) return // guard: nunca acumular sondeos
        if (root.__cpuTempPath === "") return
        const dir = root.__cpuTempPath.slice(0, root.__cpuTempPath.lastIndexOf("/"))
        coreProbe.command = [
            "sh", "-c",
            'd="' + dir + '"; '
            + 'for f in "$d"/temp*_input; do '
            + '[ -e "$f" ] || continue; '
            + 'l="${f%_input}_label"; n="${f##*/}"; n="${n#temp}"; '
            + 'printf "%s|%s|%s\n" "${n%_input}" '
            + '"$(cat "$f" 2>/dev/null)" "$(cat "$l" 2>/dev/null)"; '
            + "done"
        ]
        coreProbe.running = true
    }

    property Process coreProbe: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.__parseCoreTemps(text)
        }
    }

    // El glob ordena lexicográficamente (temp1, temp10, temp14, temp2...), así
    // que se reordena por el índice numérico para que el heatmap salga en orden
    // real de núcleo y no 1, 10, 14, 2...
    function __parseCoreTemps(out) {
        const list = []
        const lines = out.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split("|")
            if (parts.length < 2) continue
            const num = parseInt(parts[0], 10)
            const milli = Number(parts[1])
            if (isNaN(num) || isNaN(milli) || milli <= 0) continue
            const label = parts.length > 2 && parts[2].trim() !== ""
                ? parts[2].trim()
                : "Núcleo " + num
            list.push({ num: num, label: label, temp: Math.round(milli / 1000) })
        }
        if (list.length > 0) {
            list.sort((a, b) => a.num - b.num)
            root.coreTemps = list
        }
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
    property string __nvmeTemp2Path: ""

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

    on__NvmeTemp2PathChanged: {
        if (root.__nvmeTemp2Path !== "")
            nvmeTemp2File.path = Qt.resolvedUrl("file://" + root.__nvmeTemp2Path)
    }

    property FileView cpuTempFile: FileView { blockLoading: false; watchChanges: false }
    property FileView laptopTempFile: FileView { blockLoading: false; watchChanges: false }
    property FileView nvmeTempFile: FileView { blockLoading: false; watchChanges: false }
    property FileView nvmeTemp2File: FileView { blockLoading: false; watchChanges: false }

    property Process probeProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // Una línea: "<cpu> <laptop> <nvme> <nvme2>" (vacíos si no
                // existen). El segundo sensor del NVMe no siempre está, por eso
                // va aparte: se resuelve a temp2_input si el dispositivo lo
                // expone (el kernel lo llama "Sensor 1").
                const parts = text.trim().split(/\s+/)
                root.__cpuTempPath = parts[0] ?? ""
                root.__laptopTempPath = parts[1] ?? ""
                root.__nvmeTempPath = parts[2] ?? ""
                root.__nvmeTemp2Path = parts[3] ?? ""
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
            "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,"
                + "clocks.current.graphics,clocks.current.memory,pstate,power.draw,driver_version",
            "--format=csv,noheader,nounits"
        ]
        gpuProcess.running = true
    }

    // nvidia-smi devuelve "[N/A]" en los campos no soportados (p.ej. power.draw
    // sin límite, o clocks en una laptop sin panel activo): se normalizan a
    // null para que la UI pueda ocultar el dato en vez de pintar "N/A".
    function __gpuNum(s) {
        if (s === undefined || s === "" || s === "[N/A]" || s === "Not Supported")
            return null
        const n = Number(s)
        return isNaN(n) ? null : n
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
        root.gpuCoreClockMhz = root.__gpuNum(p[5]) ?? 0
        root.gpuMemClockMhz = root.__gpuNum(p[6]) ?? 0
        root.gpuPstate = p[7] !== "[N/A]" ? p[7] : ""
        const w = root.__gpuNum(p[8])
        root.gpuPowerW = w === null ? 0 : w
        root.gpuDriver = p.length > 9 && p[9] !== "[N/A]" ? p[9] : ""
        root.gpuAvailable = true
    }

    Component.onCompleted: {
        probeProcess.command = ["sh", "-c", 'cpu=""; lap=""; ssd=""; ssd2=""; for d in /sys/class/hwmon/hwmon*; do n=$(cat "$d/name" 2>/dev/null); case "$n" in coretemp|k10temp|zenpower|cpu_thermal) [ -z "$cpu" ] && cpu="$d/temp1_input";; acpitz*) [ -z "$lap" ] && lap="$d/temp1_input";; nvme) [ -z "$ssd" ] && { ssd="$d/temp1_input"; [ -e "$d/temp2_input" ] && ssd2="$d/temp2_input"; };; esac; done; echo "$cpu $lap $ssd $ssd2"']
        probeProcess.running = true
    }
}
