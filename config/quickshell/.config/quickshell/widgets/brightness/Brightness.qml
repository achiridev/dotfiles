// widgets/brightness/Brightness.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.globals

// Widget de barra para el brillo de pantalla. Hover abre el popup;
// rueda del ratón sube/baja en 1% y clic izquierdo alterna el popup.
Item {
    id: root

    implicitWidth: box.implicitWidth
    implicitHeight: AppTheme.heightBar

    property bool popupOpen: false

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool shouldOpen: hovered || popup.hovered

    onShouldOpenChanged: {
        if (root.shouldOpen) {
            closeTimer.stop()
            root.popupOpen = true
        } else {
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

            Text {
                text: BrightnessService.screenGlyph()
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.color3
            }

            Text {
                text: BrightnessService.screenPercent + "%"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.fg
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.popupOpen = !root.popupOpen
            }
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) BrightnessService.increaseScreen()
            else BrightnessService.decreaseScreen()
        }
    }

    BrightnessPopup {
        id: popup
        anchorItem: root
        requestOpen: root.popupOpen
    }
}
