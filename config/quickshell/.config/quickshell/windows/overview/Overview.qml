// windows/overview/Overview.qml
// Ventana del workspace overview: un PanelWindow fullscreen por monitor con
// backdrop, blur (layerrule "overview-blur"), captura exclusiva del foco de
// teclado, cierre por Esc/Enter/click-fuera/pérdida de foco y navegación por
// teclado (flechas, hjkl y números).
// Adaptado de Shanu-Kumawat/quickshell-overview (modules/overview/Overview.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.globals
import qs.services
import qs.widgets.overview

Scope {
    id: overviewScope

    Variants {
        id: overviewVariants
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
            property bool blurEnabled: AppTheme.overviewBlur
            property bool backdropEnabled: AppTheme.overviewBackdrop
            property real backdropOpacity: Math.max(0, Math.min(1, AppTheme.overviewBackdropOpacity))
            property bool closeOnFocusLoss: AppTheme.overviewCloseOnFocusLoss

            screen: modelData
            visible: OverviewService.overviewOpen

            // El namespace determina si la capa recibe blur de Hyprland
            // (layerrule "overview-blur" en look.lua).
            WlrLayershell.namespace: root.blurEnabled ? "quickshell:overview-blur" : "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            HyprlandFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: root.monitorIsFocused
                active: false
                onCleared: () => {
                    // Solo el monitor dueño del grab puede cerrar el overview.
                    if (root.closeOnFocusLoss && !active && canBeActive)
                        OverviewService.close()
                }
            }

            Connections {
                target: OverviewService

                function onOverviewOpenChanged() {
                    if (OverviewService.overviewOpen) {
                        delayedGrabTimer.start()
                    } else {
                        grab.active = false
                    }
                }
            }

            // Transferir el grab al monitor recién enfocado.
            Connections {
                target: Hyprland

                function onFocusedMonitorChanged() {
                    if (!OverviewService.overviewOpen)
                        return
                    if (root.monitorIsFocused && !grab.active) {
                        grab.active = true
                    } else if (!root.monitorIsFocused && grab.active) {
                        grab.active = false
                    }
                }
            }

            // Retraso para que las superficies estén listas antes del grab.
            Timer {
                id: delayedGrabTimer
                interval: AppTheme.overviewRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return
                    grab.active = OverviewService.overviewOpen
                }
            }

            // Mantener la superficie fullscreen para que el blur/backdrop no
            // queden limitados al tamaño del contenido.
            implicitWidth: screen.width
            implicitHeight: screen.height

            Item {
                id: keyHandler
                anchors.fill: parent
                visible: OverviewService.overviewOpen
                focus: OverviewService.overviewOpen
                z: 0

                Rectangle {
                    id: backdropLayer
                    anchors.fill: parent
                    visible: root.backdropEnabled
                    color: "#000000"
                    opacity: root.backdropOpacity
                    z: 0
                }

                // Clic fuera del panel: cierra el overview.
                MouseArea {
                    id: outsideClickCatcher
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    enabled: root.closeOnFocusLoss && OverviewService.overviewOpen
                    z: 0
                    onPressed: mouse => {
                        OverviewService.close()
                        mouse.accepted = true
                    }
                }

                Keys.onPressed: event => {
                    // Cerrar con Escape o Enter.
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return) {
                        OverviewService.close()
                        event.accepted = true
                        return
                    }

                    const isArrow = event.key === Qt.Key_Left || event.key === Qt.Key_H ||
                        event.key === Qt.Key_Right || event.key === Qt.Key_L ||
                        event.key === Qt.Key_Up || event.key === Qt.Key_K ||
                        event.key === Qt.Key_Down || event.key === Qt.Key_J
                    const isNumber = (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) ||
                        event.key === Qt.Key_0
                    if (!isArrow && !isNumber)
                        return

                    const rows = AppTheme.overviewRows
                    const columns = AppTheme.overviewColumns
                    const workspacesPerGroup = rows * columns
                    const currentId = root.monitor?.activeWorkspace?.id ?? 1
                    const currentGroup = Math.floor((currentId - 1) / workspacesPerGroup)
                    const minWorkspaceId = currentGroup * workspacesPerGroup + 1
                    const maxWorkspaceId = minWorkspaceId + workspacesPerGroup - 1

                    const clampedIndex = Math.max(0, Math.min(workspacesPerGroup - 1, currentId - minWorkspaceId))
                    let targetRow = Math.floor(clampedIndex / columns)
                    let targetColumn = clampedIndex % columns
                    let targetId = null

                    // Flechas y hjkl (vim), con wrap en los bordes.
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        targetColumn = (targetColumn - 1 + columns) % columns
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        targetColumn = (targetColumn + 1) % columns
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        targetRow = (targetRow - 1 + rows) % rows
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        targetRow = (targetRow + 1) % rows
                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        // 1-9 → posición 1-9 dentro del grupo.
                        const position = event.key - Qt.Key_0
                        if (position <= workspacesPerGroup)
                            targetId = minWorkspaceId + position - 1
                    } else if (event.key === Qt.Key_0) {
                        // 0 → 10ª posición del grupo.
                        if (workspacesPerGroup >= 10)
                            targetId = minWorkspaceId + 9
                    }

                    if (targetId === null) {
                        targetId = minWorkspaceId + targetRow * columns + targetColumn
                    }

                    const clampedTarget = Math.max(minWorkspaceId, Math.min(maxWorkspaceId, targetId))
                    OverviewService.focusWorkspace(clampedTarget)
                    event.accepted = true
                }
            }

            ColumnLayout {
                visible: OverviewService.overviewOpen
                z: 1
                anchors.centerIn: parent

                // Solo se instancia cuando se abre el overview (evita warnings
                // de iconos con datos vacíos y trabajo de captura en idle).
                Loader {
                    active: OverviewService.overviewOpen
                    sourceComponent: OverviewWidget {
                        panelWindow: root
                        visible: true
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "overview"

        function toggle() { OverviewService.toggle() }
        function close() { OverviewService.close() }
        function open() { OverviewService.open() }
    }
}
