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
    property var colors: {
        try {
            return JSON.parse(wallustFile.text())
        } catch (e) {
            return null
        }
    }

    // 3. Paleta de Colores Dinámica (Con Fallbacks estilo Catppuccin Mocha)
    readonly property color bg: colors ? colors.special.background : "#1e1e2e"
    readonly property color fg: colors ? colors.special.foreground : "#cdd6f4"
    readonly property color cursor: colors ? colors.special.cursor : "#f5e0dc"

    readonly property color borderColor: Qt.alpha(root.fg, 0.3)

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

    // Texto y superficies derivados (usar estos y no hardcodear alphas)
    readonly property color textSecondary: Qt.alpha(root.fg, 0.6)
    readonly property color textTertiary: Qt.alpha(root.fg, 0.4)
    // Overlay para estados hover sobre superficies.
    readonly property color surface: Qt.alpha(root.fg, 0.08)
    // Fondo sólido para superficies elevadas (popups, tarjetas).
    readonly property color bgPopup: Qt.alpha(root.bg, 0.92)

    // 4. Sistema de Diseño (Métricas fijas de UI)
    // Inter no estaba instalada (fc-match caía a Noto Sans); usamos una fuente
    // presente para que el diseño renderice como se espera en todos los widgets.
    readonly property string fontLayout: "Noto Sans"
    readonly property string fontMono: "JetBrainsMono Nerd Font"

    readonly property int fontTiny: 10
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
    readonly property color bgModule: Qt.alpha(root.bg, 0.85)
    // Hover para módulos de barra: mismo alfa que bgModule para que la
    // ColorAnimation no atraviese valores casi transparentes (evita el flash).
    readonly property color bgModuleHover: Qt.lighter(root.bgModule, 1.2)

    // 5. Workspace Overview (SUPER+TAB)
    // Efectos
    readonly property bool overviewBlur: true
    readonly property bool overviewBackdrop: true
    readonly property real overviewBackdropOpacity: 0.35
    readonly property bool overviewCloseOnFocusLoss: true
    // Timing
    readonly property int overviewEventDebounceMs: 40
    readonly property int overviewRaceConditionDelay: 150
    // Grid
    readonly property int overviewRows: 2
    readonly property int overviewColumns: 5
    readonly property real overviewScale: 0.16
    readonly property real overviewSpacing: 5
    readonly property real overviewPanelPadding: 10
    readonly property real overviewPanelOpacity: 0.92
    readonly property real overviewWorkspaceOpacity: 0.86
    readonly property real overviewWorkspaceNumberBaseSize: 250
    readonly property bool overviewHideEmptyRows: true
    // Previews
    readonly property bool overviewPreviewsEnabled: true
    readonly property string overviewPreviewMode: "live"
    readonly property int overviewPreviewRecaptureDelayMs: 60
    readonly property real overviewIconToWindowRatio: 0.25
    // Special workspaces
    readonly property bool overviewShowSpecialWorkspaces: true
    readonly property int overviewSpecialColumns: 5
}
