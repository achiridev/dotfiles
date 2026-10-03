// themes/BatteryFullTheme.qml
// Tema de batería ALTA (≥ 80% charging): "desconecta el cargador".
//
// Se activa con:  notify-send -a "batteryFull" -u normal "80%"
//
// Es un aviso de "todo bien", así que este SÍ expira solo (es un dato
// que se queda obsoleto rápido). Color de éxito y sin medidor.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Widgets

import qs.globals
import qs.services

Singleton {
    id: theme

    readonly property int percentage: BatteryService.percentage
    readonly property bool isCharging: BatteryService.isCharging

    readonly property color accent: AppTheme.success

    // Aviso informativo: expira con el timeout normal.
    readonly property int timeoutMs: AppTheme.notificationsTimeoutNormal * 1000

    // Glifo de fuente (mismo criterio que BatteryTheme: `glyph`, no `icon`).
    // U+F240 = battery-full.
    readonly property string glyph: "\uf240"

    readonly property string defaultSummary: "⚡ Batería cargada"
    readonly property string defaultBody: percentage + "% · puedes desconectar el cargador"

    readonly property string badgeText: percentage + "%"

    readonly property bool showGauge: false
    readonly property real gaugeValue: 1.0
}