// widgets/workspaces/Workspaces.qml
import QtQuick

import qs.services
import qs.globals

Rectangle {
    color: AppTheme.bg
    radius: 12

    implicitWidth: row.implicitWidth + 8 // +8 para un ligero padding interno
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4 // Un poco más de espacio luce mejor con el efecto píldora

        Repeater {
            model: WorkspacesService.visibleWorkspaces
            WorkspaceButton {
                workspaceId: modelData
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: (wheel) => {
            // angleDelta.y trae el giro de la rueda (positivo = arriba, negativo = abajo)
            WorkspacesService.scroll(wheel.angleDelta.y)
        }
    }

}