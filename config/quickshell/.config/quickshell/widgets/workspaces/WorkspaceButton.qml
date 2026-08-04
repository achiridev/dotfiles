// widgets/workspaces/WorkspaceButton.qml
import QtQuick

import qs.services
import qs.globals

Rectangle {
    property var workspaceId

    readonly property bool activeState: workspaceId === "special"
        ? WorkspacesService.isSpecialActive
        : WorkspacesService.activeWorkspaceId === workspaceId

    readonly property bool existsState: WorkspacesService.exists(workspaceId)
    readonly property bool hovered: mouseArea.containsMouse

    width: activeState ? 48 : 34
    height: AppTheme.heightBar - 4
    radius: 8

    // Lógica de color de fondo movida aquí para ser reactiva
    color: hovered
        ? WorkspacesService.backgroundHover
        : (activeState ? AppTheme.color4 : (existsState ? Qt.alpha(AppTheme.color4, 0.45) : "transparent"))

    Behavior on width {
        NumberAnimation { duration: 250; easing.type: Easing.OutExpo }
    }

    Behavior on color {
        ColorAnimation { duration: 180 }
    }

    Text {
        anchors.centerIn: parent
        text: workspaceId === "special" ? String.fromCodePoint(0xf04ce) : workspaceId
        font.pixelSize: 14
        font.bold: activeState


        color: activeState
            ? Qt.alpha(AppTheme.fg, 0.9)
            : (existsState ? Qt.alpha(AppTheme.fg, 0.8) : Qt.alpha(AppTheme.fg, 0.4))

        Behavior on color {
            ColorAnimation { duration: 180 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                WorkspacesService.switchTo(workspaceId)
            } else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                WorkspacesService.toggleSpecial()
            }
        }
    }
}