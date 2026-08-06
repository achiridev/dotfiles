// widgets/workspaces/WorkspaceButton.qml
import QtQuick

import qs.services
import qs.globals

Rectangle {
    id: root

    property var workspaceId

    readonly property bool special: workspaceId === "special"

    readonly property bool activeState: special
        ? WorkspacesService.isSpecialActive
        : WorkspacesService.activeWorkspaceId === workspaceId

    readonly property bool existsState: WorkspacesService.exists(workspaceId)
    readonly property bool hovered: mouseArea.containsMouse

    width: activeState ? 48 : 34
    height: AppTheme.heightBar - 4
    radius: AppTheme.radiusSmall

    color: activeState
        ? AppTheme.color4
        : (hovered ? Qt.alpha(AppTheme.fg, 0.15) : (existsState ? Qt.alpha(AppTheme.fg, 0.12) : "transparent"))

    Behavior on width {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Text {
        anchors.centerIn: parent

        text: root.special ? String.fromCodePoint(0xf04ce) : root.workspaceId

        font.family: root.special ? AppTheme.fontMono : AppTheme.fontLayout
        font.pixelSize: AppTheme.fontBase
        font.weight: root.activeState ? Font.Bold : Font.Medium

        color: root.activeState
            ? Qt.alpha(AppTheme.bg, 0.9)
            : (root.existsState ? Qt.alpha(AppTheme.fg, 0.8) : Qt.alpha(AppTheme.fg, 0.4))

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
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
