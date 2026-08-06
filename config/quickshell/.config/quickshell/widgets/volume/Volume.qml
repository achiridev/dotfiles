import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.globals

Item {
    id: root

    implicitWidth: box.implicitWidth
    implicitHeight: AppTheme.heightBar

    property bool popupOpen: false

    // HoverHandler reporta hover sin robar eventos de los MouseArea hijos
    // (a diferencia de MouseArea.containsMouse, que solo es true en el topmost).
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool shouldOpen: hovered || popup.hovered

    onShouldOpenChanged: {
        if (root.shouldOpen) {
            closeTimer.stop()
            root.popupOpen = true
        } else {
            // Retardo corto para no cerrar al cruzar bordes entre widget y popup.
            closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: 150
        onTriggered: root.popupOpen = false
    }

    HoverHandler {
        id: hoverHandler
    }

    Rectangle {
        id: box

        anchors.fill: parent
        implicitWidth: content.implicitWidth + AppTheme.paddingBase * 2
        radius: AppTheme.radius
        border.width: 1
        border.color: AppTheme.borderColor
        color: root.hovered ? AppTheme.bgModuleHover : AppTheme.bgModule

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: AppTheme.paddingSmall
            readonly property color textColor: AppTheme.color6 // 4 o 6

            Text {
                text: AudioService.volumeGlyph()
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold // Font.Bold
                color: content.textColor // muted ? AppTheme.critical : Qt.alpha(AppTheme.fg, 0.6)
            }

            Text {
                visible: !AudioService.muted
                text: AudioService.volumePercent + "%"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold // Font.Bold
                color: content.textColor
            }

            Text {
                visible: AudioService.micMuted
                text: "󰍭"
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                color: content.textColor // AppTheme.critical
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Solo hover: click izquierdo ya no togglea el popup.
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                AudioService.toggleMute()
            } else if (mouse.button === Qt.MiddleButton) {
                AudioService.toggleMicMute()
            }
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) AudioService.increaseVolume()
            else AudioService.decreaseVolume()
        }
    }

    VolumePopup {
        id: popup
        anchorItem: root
        requestOpen: root.popupOpen
    }
}
