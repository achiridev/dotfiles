// windows/bar/Left.qml
import QtQuick
import QtQuick.Layouts
import qs.widgets.workspaces
import qs.widgets.clock
import qs.widgets.control

RowLayout {
    anchors {
        left: parent.left
        top: parent.top
        bottom: parent.bottom
        leftMargin: 8
    }
    spacing: 8

    ControlButton {}
    Clock {}
    Workspaces {}
}
