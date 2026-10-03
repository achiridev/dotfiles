// themes/BatteryTheme.qml
// Tema de batería BAJA (≤ 20% discharging).
//
// Se activa con:  notify-send -a "battery" -u critical "15%"
//
// Diferencias con una notificación normal:
//   * No expira sola (timeoutMs: 0): un aviso de batería baja no debe
//     desaparecer; se cierra con el ✕ o con "limpiar" del popup.
//   * Color propio por franja de nivel (rojo ≤15%, amarillo hasta 30%).
//   * Icono de batería real y barra de nivel dibujada.
//
// Los datos NO vienen por D-Bus: el daemon ya tiene BatteryService con UPower
// en vivo, así que el nivel y el tiempo restante son los reales, no los que
// el script pudo mandar.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Widgets

import qs.globals
import qs.services

Singleton {
    id: theme

    // ─── Datos vivos (BatteryService) ───
    readonly property int percentage: BatteryService.percentage
    readonly property bool isCharging: BatteryService.isCharging
    readonly property string timeRemaining: BatteryService.timeRemainingText

    // Franja: 0 = crítica, 1 = preaviso, 2 = normal.
    readonly property int level: percentage <= 15 ? 0 : (percentage <= 30 ? 1 : 2)

    // ─── Estilo propio del tema ───
    readonly property color accent: level === 0 ? AppTheme.critical
                                               : (level === 1 ? AppTheme.warning
                                                              : AppTheme.success)

    // 0 = persistente (no expira). Es lo pedido: el aviso de batería baja se
    // cierra solo si el usuario lo cierra a mano.
    readonly property int timeoutMs: 0

    // Glifo de fuente (Font Awesome via AppTheme.fontMono / JetBrainsMono
    // Nerd Font). Se llama `glyph` y NO `icon`: los `icon` se resuelven con
    // Quickshell.iconPath(), que busca un ARCHIVO, y un glifo de fuente no
    // existe como archivo (daba tofu + "Could not load icon").
    // U+F0E7 = bolt (nivel critico), U+F240 = battery-full.
    readonly property string glyph: level === 0 ? "\uf0e7" : "\uf240"

    // Textos que el toast usa si el app no los mandó.
    readonly property string defaultSummary: level === 0 ? "⚠ Batería muy baja"
                                                       : "⚠ Batería baja"
    readonly property string defaultBody: percentage + "% · " + timeRemaining + " restante"

    // Etiqueta corta de la franja, para el badge del centro.
    readonly property string badgeText: percentage + "%"

    // ¿El tema trae imagen/medidor propio? (lo usa el toast)
    readonly property bool showGauge: true
    readonly property real gaugeValue: percentage / 100.0
}