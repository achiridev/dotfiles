// windows/bar/Left.qml
import QtQuick
import QtQuick.Layouts
import qs.widgets.workspaces

RowLayout {
    anchors {
        left: parent.left
        top: parent.top
        bottom: parent.bottom
        leftMargin: 8
    }
    spacing: 8

    Workspaces {}
}