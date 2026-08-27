// windows/wallpapers/WallpapersWindow.qml
// Overlay fullscreen del picker de fondos: una ventana por monitor, backdrop,
// blur (namespace "quickshell:wallpapers-blur"), captura exclusiva del teclado
// y cierre por Esc/click-fuera/pérdida de foco. Se abre con IPC:
//   quickshell ipc call wallpapers toggle
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.globals
import qs.services
import qs.widgets.wallpapers

Scope {
    id: wallpapersScope

    Variants {
        id: wallpapersVariants
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: Hyprland.focusedMonitor?.id == monitor?.id

            screen: modelData
            visible: WallpaperService.open

            WlrLayershell.namespace: AppTheme.wpBlur ? "quickshell:wallpapers-blur" : "quickshell:wallpapers"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Mantener la superficie fullscreen para blur/backdrop completos.
            implicitWidth: screen.width
            implicitHeight: screen.height

            HyprlandFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: root.monitorIsFocused
                active: false
                onCleared: () => {
                    // Nunca cerrar mientras se está aplicando: `hyprctl reload`
                    // (dentro de wallpaper.sh) revuelve el foco y dispararía el
                    // cierre; el apply cierra de forma determinista al terminar.
                    if (AppTheme.wpCloseOnFocusLoss && !active && canBeActive
                        && !WallpaperService.applyingId)
                        WallpaperService.close()
                }
            }

            Connections {
                target: WallpaperService

                function onOpenChanged() {
                    if (WallpaperService.open) {
                        delayedGrabTimer.start()
                    } else {
                        grab.active = false
                    }
                }

                // Al terminar cualquier apply la ventana sigue abierta un instante
                // ("Aplicando…" / caso Next-Previous): re-grab si el foco aleteó.
                function onApplyingIdChanged() {
                    if (!WallpaperService.applyingId && WallpaperService.open && !grab.active)
                        delayedGrabTimer.start()
                }
            }

            Connections {
                target: Hyprland

                function onFocusedMonitorChanged() {
                    if (!WallpaperService.open)
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
                    grab.active = WallpaperService.open
                }
            }

            Item {
                id: contentLayer
                anchors.fill: parent
                visible: WallpaperService.open

                Rectangle {
                    id: backdrop
                    anchors.fill: parent
                    visible: AppTheme.wpBackdrop
                    color: "#000000"
                    opacity: AppTheme.wpBackdropOpacity
                }

                MouseArea {
                    id: outsideClickCatcher
                    anchors.fill: parent
                    enabled: AppTheme.wpCloseOnFocusLoss && WallpaperService.open
                    onPressed: mouse => {
                        WallpaperService.close()
                        mouse.accepted = true
                    }
                }

                Rectangle {
                    id: appCard
                    anchors.centerIn: parent
                    width: Math.min(AppTheme.wpWindowWidth, contentLayer.width - AppTheme.paddingLarge * 2)
                    height: Math.min(AppTheme.wpWindowHeight, contentLayer.height - AppTheme.paddingLarge * 2)
                    radius: AppTheme.radiusLarge
                    color: AppTheme.bgPopup
                    border.width: 1
                    border.color: AppTheme.borderColor
                    clip: true

                    WallpaperApp {
                        anchors.fill: parent
                        focus: WallpaperService.open
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "wallpapers"

        function toggle() { WallpaperService.toggle() }
        function close() { WallpaperService.close() }
        function open() { WallpaperService.open = true }
    }
}