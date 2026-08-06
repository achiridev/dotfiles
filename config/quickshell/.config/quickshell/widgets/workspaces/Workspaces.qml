// widgets/workspaces/Workspaces.qml
import QtQuick

import qs.services
import qs.globals

Rectangle {
    id: root

    implicitWidth: row.implicitWidth + AppTheme.paddingBase * 2
    implicitHeight: AppTheme.heightBar

    radius: AppTheme.radius
    border.width: 1
    border.color: AppTheme.borderColor

    color: mouseArea.containsMouse ? AppTheme.bgModuleHover : AppTheme.bgModule

    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: WorkspacesService.visibleWorkspaces
            WorkspaceButton {
                workspaceId: modelData
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: (wheel) => {
            // angleDelta.y trae el giro de la rueda (positivo = arriba, negativo = abajo)
            WorkspacesService.scroll(wheel.angleDelta.y)
        }
    }

}
