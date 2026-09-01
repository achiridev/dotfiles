// windows/launcher/LauncherWindow.qml
// Overlay fullscreen del launcher Gear: una ventana por monitor, blur opcional
// (namespace "quickshell:launcher-blur"), captura exclusiva del teclado y
// cierre por Esc / click fuera / pérdida de foco. Se abre con IPC:
//   quickshell ipc call launcher toggle
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.globals
import qs.services
import qs.widgets.launcher

Scope {
    id: launcherScope

    Variants {
        id: launcherVariants
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: Hyprland.focusedMonitor?.id == monitor?.id

            screen: modelData
            visible: LauncherState.open

            WlrLayershell.namespace: AppTheme.launcherBlur ? "quickshell:launcher-blur" : "quickshell:launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            implicitWidth: screen.width
            implicitHeight: screen.height

            HyprlandFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: root.monitorIsFocused
                active: false
                onCleared: () => {
                    if (AppTheme.launcherCloseOnFocusLoss && !active && canBeActive)
                        LauncherState.close()
                }
            }

            Connections {
                target: LauncherState

                function onOpenChanged() {
                    if (LauncherState.open) {
                        delayedGrabTimer.start()
                    } else {
                        grab.active = false
                    }
                }
            }

            Connections {
                target: Hyprland

                function onFocusedMonitorChanged() {
                    if (!LauncherState.open)
                        return
                    if (root.monitorIsFocused && !grab.active) {
                        grab.active = true
                    } else if (!root.monitorIsFocused && grab.active) {
                        grab.active = false
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: AppTheme.overviewRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return
                    grab.active = LauncherState.open
                    if (LauncherState.open)
                        assembly.focusSearch()
                }
            }

            Item {
                id: contentLayer
                anchors.fill: parent
                visible: LauncherState.open

                MouseArea {
                    id: outsideClickCatcher
                    anchors.fill: parent
                    enabled: AppTheme.launcherCloseOnFocusLoss && LauncherState.open
                    onPressed: mouse => {
                        LauncherState.close()
                        mouse.accepted = true
                    }
                }

                // Ensamblaje (engranaje + satélites + hub) centrado y escalado
                // para caber completo en el monitor.
                Rectangle {
                    id: assemblyHost
                    anchors.centerIn: parent
                    width: assembly.implicitWidth
                    height: assembly.implicitHeight
                    radius: AppTheme.radiusLarge
                    color: "transparent"

                    transformOrigin: Item.Center
                    scale: assemblyHost.fitScale * (LauncherState.open ? 1.0 : 0.88)
                    opacity: LauncherState.open ? 1.0 : 0.0

                    Behavior on scale {
                        NumberAnimation { duration: AppTheme.wpAnimBase; easing.type: Easing.OutBack }
                    }
                    Behavior on opacity { NumberAnimation { duration: AppTheme.wpAnimBase; easing.type: Easing.OutCubic } }

                    readonly property real fitScale: Math.max(0.28, Math.min(
                        (contentLayer.width - AppTheme.paddingLarge * 2) / assembly.implicitWidth,
                        (contentLayer.height - AppTheme.paddingLarge * 2) / assembly.implicitHeight))

                    GearRoot {
                        id: assembly
                        anchors.centerIn: parent
                        focus: LauncherState.open
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle() { LauncherState.toggle() }
        function close() { LauncherState.close() }
        function open() { LauncherState.open = true }
    }
}