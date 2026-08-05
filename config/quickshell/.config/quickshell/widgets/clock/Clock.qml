// widgets/Clock/Clock.qml
import QtQuick
import QtQuick.Layouts
import qs.globals
import qs.services

Rectangle {
    id: root
    property color hoverBg: AppTheme.surface

    width: 94
    height: AppTheme.heightBar
    color: mouseArea.containsMouse ? hoverBg : AppTheme.bgModule

    radius: AppTheme.radius
    border.width: 1
    border.color: AppTheme.borderColor

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        readonly property color textColor: AppTheme.color5

        Text {
            text: TimeService.currentTime
            color: row.textColor
            font.pixelSize: AppTheme.fontBase
            font.weight: Font.Medium // Font.Bold
        }
        Text {
            text: TimeService.timeIcon
            color: row.textColor
            font.pixelSize: AppTheme.fontBase + 1
            font.family: AppTheme.fontMono
        }
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        // cursorShape: Qt.PointingHandCursor
    }
}
