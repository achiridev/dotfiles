// windows/bar/TopBar.qml
import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.globals

PanelWindow {
    id: barWindow

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: AppTheme.heightBar
    exclusiveZone: height
    WlrLayershell.layer: WlrLayer.Top

    color: Qt.alpha(AppTheme.bg, 0.55)

    // Submódulos independientes
    Left {}
    Center {}
    Right {}
}
