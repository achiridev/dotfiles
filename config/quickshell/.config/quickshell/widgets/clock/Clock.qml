// widgets/Clock/Clock.qml
import QtQuick
import QtQuick.Layouts
import qs.globals
import qs.services

Rectangle {
    width: 80
    height: AppTheme.heightBar
    color: AppTheme.bgModule

    radius: AppTheme.radius
    border.width: 1
    border.color: AppTheme.borderColor


    Text {
        anchors.centerIn: parent
        text: TimeService.currentTime
        color: AppTheme.fg
        font.pixelSize: AppTheme.fontBase
        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
    }
}
