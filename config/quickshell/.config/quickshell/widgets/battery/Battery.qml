// components/Battery.qml
import QtQuick
import Quickshell

import qs.services
import qs.globals

Rectangle {
    id: root

    width: 70
    height: AppTheme.heightBar
    radius: AppTheme.radius
    border.width: 1
    border.color: AppTheme.borderColor

    property color displayColor: BatteryService.color
    property bool panelOpen: false

    // El panel solo lee el estado de modos mientras está abierto.
    onPanelOpenChanged: BatteryService.detailMode = panelOpen

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

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: mouseArea.containsMouse ? Qt.alpha(AppTheme.fg, 0.12) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: BatteryService.percentage + "%"
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontBase
            color: AppTheme.fg
        }

        Text {
            text: BatteryService.batteryIcon
            font.family: AppTheme.fontMono
            font.pixelSize: AppTheme.fontBase + 1
            color: AppTheme.fg
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.panelOpen = !root.panelOpen
    }

    BatteryPanel {
        id: panel
        requestOpen: root.panelOpen
        onCloseRequested: root.panelOpen = false
    }
}

