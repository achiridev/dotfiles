// widgets/idleinhibitor/IdleInhibitor.qml
import QtQuick
import qs.globals
import qs.services

Rectangle {
    id: root

    readonly property bool active: IdleInhibitService.enabled

    width: 48
    height: AppTheme.heightBar

    radius: AppTheme.radius
    border.width: 1
    border.color: AppTheme.borderColor

    color: mouseArea.containsMouse ? AppTheme.bgModuleHover : AppTheme.bgModule

    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Text {
        anchors.centerIn: parent

        text: root.active
            ? String.fromCodePoint(0xf0599) // md-weather-sunny: pantalla despierta
            : String.fromCodePoint(0xf0594) // md-weather-night: reposo permitido

        font.family: AppTheme.fontMono
        font.pixelSize: AppTheme.fontBase + 1
        font.weight: Font.Bold

        color: root.active ? AppTheme.warning : AppTheme.fg

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: IdleInhibitService.toggle()
    }
}
