import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.widgets.visualizer

PanelWindow {
    id: root

    // capa: encima del wallpaper (Background), debajo de las ventanas normales
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-visualizer"

    // no reservar espacio: las ventanas pueden ocupar toda la pantalla igual
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: 140
    color: "transparent"

    // click-through total: nada en esta ventana es clicable
    mask: Region {}

    Visualizer {
        anchors.fill: parent
        anchors.margins: 8
    }
}
