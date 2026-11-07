// widgets/clipboard/ClipboardStyle.qml
//
// ÚNICO punto con tokens visuales del gestor de portapapeles. Para un rediseño
// completo (colores, tamaños, distribución, radios, tipografías, animaciones)
// basta con cambiar este archivo y/o reemplazar ClipboardView.qml; la lógica
// (ClipboardService / ClipboardBackend / ClipboardUtils) no se toca.
pragma Singleton

import QtQuick
import Quickshell

import qs.globals

Singleton {
    id: root

    // ============================================================
    // VENTANA / BACKDROP
    // ============================================================
    readonly property string layerNamespace: "quickshell:clipboard"
    readonly property bool closeOnFocusLoss: true
    readonly property int grabDelayMs: AppTheme.overviewRaceConditionDelay

    readonly property int windowWidth: 1000
    readonly property int windowHeight: 660
    readonly property int outerMargin: 24

    readonly property bool backdropEnabled: true
    readonly property color backdropColor: "#000000"
    readonly property real backdropOpacity: 0.5

    // ============================================================
    // SUPERFICIE PRINCIPAL
    // ============================================================
    readonly property color panelColor: Qt.alpha(AppTheme.bg, 0.97)
    readonly property color panelBorder: Qt.alpha(AppTheme.fg, 0.12)
    readonly property color divider: Qt.alpha(AppTheme.fg, 0.08)
    readonly property int panelRadius: AppTheme.radiusLarge
    readonly property int panelPadding: AppTheme.paddingLarge + AppTheme.paddingBase
    readonly property int sectionSpacing: AppTheme.paddingBase

    // ============================================================
    // COLORES SEMÁNTICOS
    // ============================================================
    readonly property color textPrimary: AppTheme.fg
    readonly property color textSecondary: AppTheme.textSecondary
    readonly property color textTertiary: AppTheme.textTertiary
    readonly property color accent: AppTheme.accent
    readonly property color danger: AppTheme.color1
    readonly property color warning: AppTheme.color3

    readonly property color textKindColor: AppTheme.color6
    readonly property color imageKindColor: AppTheme.color4
    readonly property color binaryKindColor: AppTheme.color3

    readonly property color badgeBg: Qt.alpha(AppTheme.fg, 0.06)
    readonly property color searchBg: Qt.alpha(AppTheme.fg, 0.05)
    readonly property color searchBgFocused: Qt.alpha(AppTheme.fg, 0.08)
    readonly property color searchBorder: Qt.alpha(AppTheme.fg, 0.10)
    readonly property color searchBorderFocused: Qt.alpha(AppTheme.accent, 0.6)

    readonly property color rowColor: "transparent"
    readonly property color rowHover: Qt.alpha(AppTheme.fg, 0.06)
    readonly property color rowSelected: Qt.alpha(AppTheme.accent, 0.15)
    readonly property color rowSelectedBorder: Qt.alpha(AppTheme.accent, 0.55)

    readonly property color buttonBg: Qt.alpha(AppTheme.fg, 0.05)
    readonly property color buttonHover: Qt.alpha(AppTheme.fg, 0.10)
    readonly property color buttonDangerBg: Qt.alpha(AppTheme.color1, 0.16)
    readonly property color buttonDangerHover: Qt.alpha(AppTheme.color1, 0.26)

    readonly property color previewBg: Qt.alpha(AppTheme.fg, 0.025)
    readonly property color selectionColor: Qt.alpha(AppTheme.accent, 0.35)
    readonly property color scrollbar: Qt.alpha(AppTheme.fg, 0.22)

    // ============================================================
    // MÉTRICAS
    // ============================================================
    readonly property int headerTitleSize: AppTheme.fontLarge + 2
    readonly property int listWidth: 430
    readonly property int searchHeight: 42
    readonly property int searchRadius: AppTheme.radius
    readonly property int rowHeight: 64
    readonly property int rowSpacing: AppTheme.paddingSmall
    readonly property int rowRadius: AppTheme.radius
    readonly property int listCacheBuffer: 320

    readonly property int previewPadding: AppTheme.paddingLarge
    readonly property int imagePreviewMaxPx: 1400
    readonly property int textPreviewSize: AppTheme.fontBase
    readonly property int metaSize: AppTheme.fontSmall
    readonly property int hintSize: AppTheme.fontSmall
    readonly property int titleSize: root.headerTitleSize

    readonly property int sectionPadding: AppTheme.paddingBase
    readonly property int footerHeight: 44

    // ============================================================
    // ANIMACIONES (valores para que el rediseño futuro las cambie)
    // ============================================================
    readonly property int animFast: 120
    readonly property int animBase: 180
}
