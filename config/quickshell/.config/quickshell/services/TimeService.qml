// services/TimeService.qml
import QtQuick
import Quickshell

pragma Singleton

Item {
    readonly property string timeIcon: String.fromCodePoint(0xf0954) || "󰥔"
    property string currentTime: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: currentTime = Qt.formatDateTime(new Date(), "hh:mm:ss")
    }
}
