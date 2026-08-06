// shell.qml - Entry point de Quickshell
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.windows.bar
import qs.windows.visualizer
import qs.windows.overview

ShellRoot {
    Bar {}

    Variants {
        model: Quickshell.screens
        delegate: Component {
            VisualizerWindow {
                required property var modelData
                screen: modelData
            }
        }
    }

    Overview {}
}
