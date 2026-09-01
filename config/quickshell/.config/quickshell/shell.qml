// shell.qml - Entry point de Quickshell
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.windows.bar
import qs.windows.visualizer
import qs.windows.overview
import qs.windows.wallpapers
import qs.windows.launcher
import qs.windows.activate

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
    WallpapersWindow {}
    LauncherWindow {}
    ActivateWindow {}
}
