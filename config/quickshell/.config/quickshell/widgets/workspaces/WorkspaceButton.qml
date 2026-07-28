import QtQuick

import qs.services
import qs.globals

Rectangle {

    property int workspaceId

    width: 34
    height: AppTheme.heightBar - 4

    radius: 8

    property bool hovered: false
    color: hovered
        ? WorkspacesService.backgroundHover
        : WorkspacesService.background(workspaceId)

    Behavior on color {
        ColorAnimation {
            duration: 180
        }
    }

    Text {

        anchors.centerIn: parent

        text: workspaceId

        font.pixelSize: 14
        font.bold: true

        color: WorkspacesService.textColor(workspaceId)

        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }

    }

    MouseArea {

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: parent.hovered = true
        onExited: parent.hovered = false

        onClicked:
            WorkspacesService.switchTo(workspaceId)

    }

}
