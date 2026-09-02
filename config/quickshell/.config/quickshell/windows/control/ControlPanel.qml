// windows/control/ControlPanel.qml
// Panel de control flotante (ventana real xdg que Hyprland gestiona, como el
// panel de batería). Permite activar/desactivar los componentes de Quickshell
// (Bar, Overview, Wallpapers, Launcher, Activate, Visualizer). Cada toggle
// escribe ControlState.<x>Enabled, que alimenta los Loaders de shell.qml.
// El panel en sí es PERMANENTE: no se auto-desactiva ni se cierra por foco.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell._Window
import Quickshell.Io
import qs.globals

FloatingWindow {
    id: panel

    // ============================ SUB-COMPONENTES ============================
    component ToggleRow: Rectangle {
        id: row
        property string label: ""
        property string icon: ""
        property bool checked: false
        property var onToggled: null

        readonly property color activeColor: checked ? AppTheme.accent : AppTheme.color8

        Layout.fillWidth: true
        implicitHeight: rowRow.implicitHeight + AppTheme.paddingBase * 2
        radius: AppTheme.radiusSmall
        color: checked ? Qt.alpha(AppTheme.accent, 0.14)
             : ma.containsMouse ? AppTheme.surface
             : Qt.alpha(AppTheme.fg, 0.03)
        border.width: 1
        border.color: checked ? Qt.alpha(AppTheme.accent, 0.5) : Qt.alpha(AppTheme.fg, 0.08)

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: rowRow
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: AppTheme.paddingBase

            Text {
                text: row.icon
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontLarge
                color: row.activeColor

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                Layout.fillWidth: true
                text: row.label
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: checked ? AppTheme.fg : AppTheme.textSecondary

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Switch on/off
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 24
                radius: height / 2
                color: checked ? Qt.alpha(row.activeColor, 0.85) : Qt.alpha(AppTheme.fg, 0.12)
                border.width: 1
                border.color: checked ? row.activeColor : Qt.alpha(AppTheme.fg, 0.2)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: checked ? parent.width - height - 2 : 2
                    width: 20
                    height: 20
                    radius: height / 2
                    color: "#ffffff"

                    Behavior on anchors.leftMargin { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (row.onToggled) row.onToggled()
            }
        }
    }

    // ================================ ESTADO =================================
    property bool requestOpen: false
    property bool shown: false

    readonly property int cardWidth: 360

    // Identificador para la windowrule de Hyprland (float + center).
    title: "qs-control-panel"

    visible: shown
    color: "transparent"

    implicitWidth: cardWidth
    implicitHeight: layout.implicitHeight + (AppTheme.paddingLarge + AppTheme.paddingBase) * 2

    onRequestOpenChanged: {
        if (requestOpen) {
            closeAnim.stop()
            if (!shown) {
                shown = true
            } else {
                __resetCard()
                openAnim.start()
            }
        } else if (shown && !closeAnim.running) {
            closeAnim.start()
        }
    }

    onShownChanged: {
        if (shown) {
            __resetCard()
            openAnim.start()
        }
    }

    function __resetCard() {
        card.opacity = 0
        card.scale = 0.92
        card.y = 10
    }

    Rectangle {
        id: card
        width: panel.width
        height: panel.height
        radius: AppTheme.radiusLarge
        color: AppTheme.bgPopup
        border.width: 1
        border.color: AppTheme.borderColor
        transformOrigin: Item.Center

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: AppTheme.paddingLarge + AppTheme.paddingBase
            spacing: AppTheme.paddingSmall

            // ============================= HEADER ============================
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: AppTheme.radiusSmall
                    color: Qt.alpha(AppTheme.accent, 0.14)
                    border.width: 1
                    border.color: Qt.alpha(AppTheme.accent, 0.32)

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xe732) // dev-archlinux
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontLarge
                        color: AppTheme.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: "CONTROL"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontLarge
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                        color: AppTheme.fg
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Componentes de Quickshell"
                        elide: Text.ElideRight
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.textSecondary
                    }
                }

                Rectangle {
                    id: closeButton
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: AppTheme.radiusSmall
                    color: closeMa.containsMouse ? AppTheme.surface : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        font.weight: Font.Bold
                        color: closeMa.containsMouse ? AppTheme.fg : AppTheme.textSecondary
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ControlState.closePanel()
                    }
                }
            }

            // ============================ DIVISOR ===========================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            // ======================= LISTA DE COMPONENTES ===================
            ToggleRow {
                label: "Bar"
                icon: String.fromCodePoint(0xf0c9) // hamburguesa/menú
                checked: ControlState.barEnabled
                onToggled: () => { ControlState.barEnabled = !ControlState.barEnabled }
            }

            ToggleRow {
                label: "Overview"
                icon: String.fromCodePoint(0xf009) // cuadrícula
                checked: ControlState.overviewEnabled
                onToggled: () => { ControlState.overviewEnabled = !ControlState.overviewEnabled }
            }

            ToggleRow {
                label: "Wallpapers"
                icon: String.fromCodePoint(0xf03e) // imagen
                checked: ControlState.wallpapersEnabled
                onToggled: () => { ControlState.wallpapersEnabled = !ControlState.wallpapersEnabled }
            }

            ToggleRow {
                label: "Launcher"
                icon: String.fromCodePoint(0xf013) // engranaje
                checked: ControlState.launcherEnabled
                onToggled: () => { ControlState.launcherEnabled = !ControlState.launcherEnabled }
            }

            ToggleRow {
                label: "Activate"
                icon: String.fromCodePoint(0xf305) // marcar/activar
                checked: ControlState.activateEnabled
                onToggled: () => { ControlState.activateEnabled = !ControlState.activateEnabled }
            }

            ToggleRow {
                label: "Visualizer"
                icon: String.fromCodePoint(0xf145) // ondas/audio
                checked: ControlState.visualizerEnabled
                onToggled: () => { ControlState.visualizerEnabled = !ControlState.visualizerEnabled }
            }

            // ============================ DIVISOR ===========================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            // ============================ FOOTER ============================
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: String.fromCodePoint(0xf0c9)
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textTertiary
                }

                Text {
                    Layout.fillWidth: true
                    text: "Activación instantánea · libera RAM"
                    elide: Text.ElideRight
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textTertiary
                }
            }
        }
    }

    // ================================ IPC ===================================
    // Expone control del panel a «quickshell ipc call control toggle».
    IpcHandler {
        target: "control"

        function toggle() { ControlState.togglePanel() }
        function open() { ControlState.openPanel() }
        function close() { ControlState.closePanel() }
    }

    // Apertura/cierre del panel (espejo de ControlState.panelOpen).
    Connections {
        target: ControlState
        function onPanelOpenChanged() {
            panel.requestOpen = ControlState.panelOpen
        }
    }
    Component.onCompleted: {
        panel.requestOpen = ControlState.panelOpen
    }

    // Apertura: fade + escala + slide sutil hacia el centro.
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "y"; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }

    // Cierre: se oculta la ventana recién cuando termina la animación.
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "scale"; to: 0.95; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "y"; to: 6; duration: 140; easing.type: Easing.InCubic }
        onFinished: panel.shown = false
    }
}
