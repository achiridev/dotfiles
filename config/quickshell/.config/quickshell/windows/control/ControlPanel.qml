// windows/control/ControlPanel.qml
// Panel de control flotante (ventana real xdg que Hyprland gestiona, como el
// panel de batería). Es un centro de control con varias secciones navegables
// por un rail lateral de iconos:
//   0 = Componentes de Quickshell (toggles)
//   1 = Colores/Wallust (temas + acento + paleta)
//   2 = Energía (modos de energía + estado del sistema)
// Cada sección es un widget independiente en widgets/control/. El panel es
// PERMANENTE: no se auto-desactiva ni se cierra por foco.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell._Window
import Quickshell.Io
import qs.globals
import qs.services
import qs.widgets.control

FloatingWindow {
    id: panel

    // ================================ ESTADO =================================
    property bool requestOpen: false
    property bool shown: false

    readonly property int cardWidth: 920
    readonly property int railWidth: 60
    readonly property int currentSection: ControlState.panelSection

    readonly property var sections: [
        { icon: String.fromCodePoint(0xf0c9), label: "Componentes" },
        { icon: String.fromCodePoint(0xf1fc), label: "Colores" },   // pincel/paleta
        { icon: String.fromCodePoint(0xf07b), label: "Energía" }
    ]

    // Identificador para la windowrule de Hyprland (float + center).
    title: "qs-control-panel"

    visible: shown
    color: "transparent"

    implicitWidth: cardWidth
    implicitHeight: 860

    // Activa la lectura de modos de BatteryService solo mientras la sección
    // de Energía está visible (polling bajo demanda).
    readonly property bool energyActive: shown && currentSection === 2
    onEnergyActiveChanged: BatteryService.detailMode = energyActive

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
            spacing: AppTheme.paddingBase

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
                        text: panel.sections[panel.currentSection].label
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

            // ===================== RAIL + CONTENIDO =====================
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: AppTheme.paddingBase

                // ---- Rail lateral de iconos ----
                ColumnLayout {
                    id: rail
                    Layout.fillWidth: false
                    Layout.preferredWidth: panel.railWidth
                    Layout.minimumWidth: panel.railWidth
                    Layout.maximumWidth: panel.railWidth
                    Layout.fillHeight: true
                    spacing: AppTheme.paddingSmall

                    Repeater {
                        model: panel.sections

                        delegate: Rectangle {
                            id: railBtn
                            required property int index
                            required property var modelData

                            readonly property bool isActive: panel.currentSection === index

                            Layout.fillWidth: true
                            Layout.preferredHeight: panel.railWidth - (AppTheme.paddingSmall * 2 + 1)
                            radius: AppTheme.radiusSmall
                            color: isActive ? Qt.alpha(AppTheme.accent, 0.16)
                                 : ma.containsMouse ? AppTheme.surface
                                 : Qt.alpha(AppTheme.fg, 0.03)
                            border.width: 1
                            border.color: isActive ? Qt.alpha(AppTheme.accent, 0.5) : Qt.alpha(AppTheme.fg, 0.08)

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.family: AppTheme.fontMono
                                font.pixelSize: AppTheme.fontLarge
                                color: isActive ? AppTheme.accent : AppTheme.textSecondary

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            ToolTip.visible: ma.containsMouse && !isActive
                            ToolTip.text: modelData.label
                            ToolTip.delay: 400

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ControlState.setSection(index)
                            }
                        }
                    }

                    // Espaciador inferior del rail.
                    Item { Layout.fillHeight: true }
                }

                // ---- Cuerpo: sección activa ----
                StackLayout {
                    id: stack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: panel.currentSection

                    ToggleSection { id: toggleSection }
                    ColorSection { id: colorSection }
                    EnergySection { id: energySection }
                }
            }
        }
    }

    // ================================ IPC ===================================
    // Expone control del panel a «quickshell ipc call control toggle».
    IpcHandler {
        target: "control"

        function toggle(): void { ControlState.togglePanel() }
        function open(): void { ControlState.openPanel() }
        function close(): void { ControlState.closePanel() }
        function section(index: int): void { ControlState.openSection(index) }
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