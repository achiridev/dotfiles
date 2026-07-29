// widgets/workspaces/Workspaces.qml
import QtQuick

import qs.services
import qs.globals

Rectangle {

    color: AppTheme.bg

    radius: 12

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {

        id: row

        anchors.centerIn: parent

        spacing: 2

        Repeater {
            model: WorkspacesService.visibleWorkspaces
            WorkspaceButton {
                workspaceId: modelData
            }
        }

    }

}
