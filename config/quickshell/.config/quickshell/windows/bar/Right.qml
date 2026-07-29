// windows/bar/Right.qml
import QtQuick
import QtQuick.Layouts
import qs.widgets.battery
import qs.widgets.powermenu

RowLayout {
    anchors {
        right: parent.right
        top: parent.top
        bottom: parent.bottom
        rightMargin: 8
    }
    spacing: 8

    Battery {}
    PowerButton {}
}
