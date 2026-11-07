// windows/clipboard/ClipboardWindow.qml
//
// Overlay fullscreen del gestor de portapapeles: una ventana por monitor,
// backdrop, captura exclusiva del teclado y cierre por Esc / clic fuera /
// pérdida de foco. Se abre con IPC:
//   quickshell ipc call clipboard toggle
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.globals
import qs.services
import qs.widgets.clipboard

Scope {
    id: clipboardScope

    Variants {
        id: clipboardVariants
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: Hyprland.focusedMonitor?.id == monitor?.id

            screen: modelData
            visible: ClipboardState.open

            WlrLayershell.namespace: ClipboardStyle.layerNamespace
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
                    if (ClipboardStyle.closeOnFocusLoss && !active && canBeActive)
                        ClipboardState.close()
                }
            }

            Connections {
                target: ClipboardState

                function onOpenChanged() {
                    if (ClipboardState.open) {
                        delayedGrabTimer.start()
                    } else {
                        grab.active = false
                    }
                }
            }

            Connections {
                target: Hyprland

                function onFocusedMonitorChanged() {
                    if (!ClipboardState.open)
                        return
                    if (root.monitorIsFocused && !grab.active) {
                        grab.active = true
                        // Al mover el foco a este monitor, el TextInput local
                        // debe recuperar el foco de teclado.
                        Qt.callLater(view.focusSearch)
                    } else if (!root.monitorIsFocused && grab.active) {
                        grab.active = false
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: ClipboardStyle.grabDelayMs
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return
                    grab.active = ClipboardState.open
                    if (ClipboardState.open)
                        view.focusSearch()
                }
            }

            Item {
                id: contentLayer
                anchors.fill: parent
                visible: ClipboardState.open

                Rectangle {
                    anchors.fill: parent
                    visible: ClipboardStyle.backdropEnabled
                    color: ClipboardStyle.backdropColor
                    opacity: ClipboardStyle.backdropOpacity
                }

                MouseArea {
                    id: outsideClickCatcher
                    anchors.fill: parent
                    enabled: ClipboardStyle.closeOnFocusLoss && ClipboardState.open
                    onPressed: mouse => {
                        ClipboardState.close()
                        mouse.accepted = true
                    }
                }

                ClipboardView {
                    id: view
                    anchors.centerIn: parent
                    width: Math.min(ClipboardStyle.windowWidth,
                                    contentLayer.width - ClipboardStyle.outerMargin * 2)
                    height: Math.min(ClipboardStyle.windowHeight,
                                     contentLayer.height - ClipboardStyle.outerMargin * 2)
                }
            }
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() { ClipboardState.toggle() }
        function open() { ClipboardState.openWindow() }
        function close() { ClipboardState.close() }
        function refresh() { ClipboardService.refresh() }
        function clear() { ClipboardService.clearAll() }
    }
}
