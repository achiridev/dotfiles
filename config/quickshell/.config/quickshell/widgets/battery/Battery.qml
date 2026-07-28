// components/Battery.qml
import QtQuick
import Quickshell

import qs.services
import qs.globals

Rectangle {
    width: 80
    height: AppTheme.heightBar
    radius: AppTheme.radius
    border.width: 1
    border.color: Qt.alpha(AppTheme.fg, 0.4)

    property color displayColor: BatteryService.color

    color: displayColor

    Behavior on displayColor {
        ColorAnimation { duration: 200 }
    }

    SequentialAnimation on displayColor {
        running: BatteryService.isWarning
        loops: Animation.Infinite

        ColorAnimation {
            to: BatteryService.colorWarning
            duration: 400
        }

        ColorAnimation {
            to: BatteryService.colorDefault
            duration: 400
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: BatteryService.batteryIcon
            font.family: AppTheme.fontMono
            font.pixelSize: AppTheme.fontLarge
            color: AppTheme.fg
        }

        Text {
            text: BatteryService.percentage + "%"
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontBase
            color: AppTheme.fg
        }

    }
}

