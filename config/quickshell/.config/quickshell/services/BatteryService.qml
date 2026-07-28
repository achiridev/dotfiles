// service/battery/BatteryService.qml
pragma Singleton
import Quickshell
import Quickshell.Services.UPower

import QtQuick
import QtQuick.Layouts
import qs.globals

// ==========================================
// SISTEMA DE BATERÍA
// ==========================================

Singleton
{
    id: root
    property var batteryInfo: UPower.displayDevice

    readonly property int percentage: Math.round(batteryInfo.percentage * 100)
    readonly property bool isCharging: batteryInfo.state === UPowerDeviceState.Charging
    readonly property bool isWarning: !isCharging && percentage < 20

    readonly property string batteryIcon: {
        if (isCharging) return String.fromCodePoint(0xf0084);
        if (percentage === 100) return String.fromCodePoint(0xf17e2);
        if (percentage > 90) return String.fromCodePoint(0xf0082);
        if (percentage > 80) return String.fromCodePoint(0xf0081);
        if (percentage > 70) return String.fromCodePoint(0xf0080);
        if (percentage > 60) return String.fromCodePoint(0xf007f);
        if (percentage > 50) return String.fromCodePoint(0xf007e);
        if (percentage > 40) return String.fromCodePoint(0xf007d);
        if (percentage > 30) return String.fromCodePoint(0xf007c);
        if (percentage > 20) return String.fromCodePoint(0xf007b);
        return String.fromCodePoint(0xf0083);
    }

    readonly property string colorCharning: "#308b5b"
    readonly property string colorWarning: "#ff5555"
    readonly property string colorDefault: Theme.color1
    readonly property string color: {
        if (isCharging && percentage < 100 ) return colorCharning
        return colorDefault
    }

}
