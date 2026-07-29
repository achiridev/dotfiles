// widgets/Clock/Clock.qml
import QtQuick
import QtQuick.Layouts
import qs.globals
import qs.services

Text {
    color: AppTheme.fg
    font.pixelSize: 14
    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
    text: TimeService.currentTime
}
