// windows/bar/Center.qml
import QtQuick
import QtQuick.Layouts
import qs.widgets.volume
import qs.widgets.music
import qs.widgets.brightness

RowLayout {
    anchors.centerIn: parent
    spacing: 8

    Volume {}
    Music {}
    Brightness {}
}
