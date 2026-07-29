// windows/bar/Center.qml
import QtQuick
import QtQuick.Layouts
import qs.widgets.clock

RowLayout {
    anchors.centerIn: parent
    spacing: 8

    Clock {}
}
