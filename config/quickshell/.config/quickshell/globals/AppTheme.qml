// globals/AppTheme.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // 1. Cargamos el archivo JSON de Wallust de forma reactiva
    property FileView wallustFile: FileView {
        path: Qt.resolvedUrl("file://" + Quickshell.env("HOME") + "/.cache/wallust/colors.json")

        blockLoading: true
        watchChanges: true

        onFileChanged: reload()
    }
    // 2. Parseamos el JSON para extraer los colores
    property var colors: JSON.parse(wallustFile.text())

    // 3. Paleta de Colores Dinámica (Con Fallbacks estilo Catppuccin Mocha)
    readonly property color bg: colors ? colors.special.background : "#1e1e2e"
    readonly property color fg: colors ? colors.special.foreground : "#cdd6f4"
    readonly property color cursor: colors ? colors.special.cursor : "#f5e0dc"

    readonly property color borderColor: Qt.alpha(AppTheme.fg, 0.3)

    // Colores base (0-7)
    readonly property color color0: colors ? colors.colors.color0 : "#11111b"
    readonly property color color1: colors ? colors.colors.color1 : "#f38ba8"
    readonly property color color2: colors ? colors.colors.color2 : "#a6e3a1"
    readonly property color color3: colors ? colors.colors.color3 : "#f9e2af"
    readonly property color color4: colors ? colors.colors.color4 : "#89b4fa"
    readonly property color color5: colors ? colors.colors.color5 : "#cba6f7"
    readonly property color color6: colors ? colors.colors.color6 : "#89dceb"
    readonly property color color7: colors ? colors.colors.color7 : "#bac2de"

    // Colores brillantes / intensos (8-15)
    readonly property color color8:  colors ? colors.colors.color8  : "#585b70"
    readonly property color color9:  colors ? colors.colors.color9  : "#f38ba8"
    readonly property color color10: colors ? colors.colors.color10 : "#a6e3a1"
    readonly property color color11: colors ? colors.colors.color11 : "#f9e2af"
    readonly property color color12: colors ? colors.colors.color12 : "#89b4fa"
    readonly property color color13: colors ? colors.colors.color13 : "#cba6f7"
    readonly property color color14: colors ? colors.colors.color14 : "#89dceb"
    readonly property color color15: colors ? colors.colors.color15 : "#a6adc8"

    // Alias semánticos (Para hacer tu UI más fácil de programar)
    readonly property color accent: color5
    readonly property color critical: color1
    readonly property color warning: color3
    readonly property color success: color2

    // 4. Sistema de Diseño (Métricas fijas de UI)
    readonly property string fontLayout: "Inter"
    readonly property string fontMono: "JetBrainsMono Nerd Font"

    readonly property int fontSmall: 11
    readonly property int fontBase: 14
    readonly property int fontLarge: 18

    readonly property int paddingSmall: 4
    readonly property int paddingBase: 8
    readonly property int paddingLarge: 12

    readonly property int radiusSmall: 4
    readonly property int radius: 8
    readonly property int radiusLarge: 12

    // Bar  (waybar es de 35 pero no ocupa todo asi que xd)
    readonly property int heightBar: 30
    readonly property color bgModule: Qt.alpha(AppTheme.bg, 0.85)
}
