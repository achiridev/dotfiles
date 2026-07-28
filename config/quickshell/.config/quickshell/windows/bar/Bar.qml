// windows/bar/Bar.qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import qs.globals
import qs.widgets.battery
import qs.widgets.workspaces

PanelWindow {
    id: barWindow

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.heightBar

    // Excluir esta zona del área de ventanas (como en Waybar)
    exclusiveZone: height

    // Layer: background, bottom, top, overlay
    WlrLayershell.layer: WlrLayer.Top

    color: Qt.alpha(Theme.bg, 0.55)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // IZQUIERDA
        Workspaces {}

        Item { Layout.fillWidth: true }  // Spacer

        // CENTRO
        Text {
            id: clock
            color: "#cdd6f4"
            font.pixelSize: 14
            anchors.centerIn: parent


            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
            }

            Component.onCompleted: text = Qt.formatDateTime(new Date(), "hh:mm:ss")
        }

        Item { Layout.fillWidth: true }  // Spacer

        // DERECHA
        Battery {}
    }
}
