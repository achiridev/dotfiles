import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

import qs.globals
import qs.services
import qs.widgets.notifications

// windows/notifications/NotificationCenter.qml
// Centro de notificaciones full-screen per-monitor (layer shell)
Scope {
    id: scope

    Variants {
        id: variants
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)

            screen: modelData
            visible: NotificationsService.notificationCenterOpen

            WlrLayershell.namespace: AppTheme.notificationsBlur ? "quickshell:notifications-blur" : "quickshell:notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Grab focus para teclado
            HyprlandFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: (Hyprland.focusedMonitor?.id === monitor?.id)
                active: root.visible
                onCleared: {
                    if (AppTheme.notificationsCloseOnFocusLoss && !active && canBeActive) {
                        NotificationsService.notificationCenterOpen = false;
                    }
                }
            }

            // Fondo semitransparente con blur opcional
            Rectangle {
                anchors.fill: parent
                radius: AppTheme.radiusLarge
                color: AppTheme.bgPopup
                border.width: 1
                border.color: AppTheme.borderColor
                opacity: 0.96
            }

            // Contenido principal
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: AppTheme.paddingLarge
                spacing: AppTheme.paddingBase

                // ─── Header ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    // Título
                    Text {
                        text: "Centro de Notificaciones"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontLarge
                        font.bold: true
                        color: AppTheme.fg
                    }

                    Item { Layout.fillWidth: true } // spacer

                    // DND Toggle
                    MouseArea {
                        id: dndBtn
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationsService.toggleDND()
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: AppTheme.radius
                            color: NotificationsService.dndEnabled ? AppTheme.critical : AppTheme.surface
                            border.width: 1
                            border.color: NotificationsService.dndEnabled ? AppTheme.critical : AppTheme.borderColor
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: NotificationsService.dndEnabled ? "\uf1f6" : "\uf0f3" // bell-slash / bell
                                    font.family: AppTheme.fontMono
                                    font.pixelSize: AppTheme.fontBase
                                    color: NotificationsService.dndEnabled ? AppTheme.bg : AppTheme.fg
                                }
                                Text {
                                    text: NotificationsService.dndEnabled ? "No Molestar" : "Activo"
                                    font.family: AppTheme.fontLayout
                                    font.pixelSize: AppTheme.fontSmall
                                    color: NotificationsService.dndEnabled ? AppTheme.bg : AppTheme.fg
                                }
                            }
                        }
                    }

                    // Clear All
                    MouseArea {
                        id: clearBtn
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 36
                        cursorShape: Qt.PointingHandCursor
                        enabled: NotificationsService.unreadCount > 0
                        onClicked: NotificationsService.clearHistory()
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: AppTheme.radius
                            color: enabled ? AppTheme.surface : Qt.alpha(AppTheme.surface, 0.5)
                            border.width: 1
                            border.color: enabled ? AppTheme.borderColor : Qt.alpha(AppTheme.borderColor, 0.5)
                            Text {
                                anchors.centerIn: parent
                                text: "\uf0c2  Limpiar" // fa-trash
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                color: enabled ? AppTheme.fg : AppTheme.textTertiary
                            }
                        }
                    }

                    // Close
                    MouseArea {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationsService.notificationCenterOpen = false
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 8
                            radius: AppTheme.radiusSmall
                            color: "transparent"
                            id: clearBtnBg
                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font.family: AppTheme.fontMono
                                font.pixelSize: AppTheme.fontBase
                                color: AppTheme.textSecondary
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        onEntered: clearBtnBg.color = AppTheme.surface
                        onExited: clearBtnBg.color = "transparent"
                    }
                }

                // ─── Divider ───
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: AppTheme.borderColor
                    opacity: 0.5
                }

                // ─── List View (historial) ───
                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: NotificationsService.historyModel
                    spacing: AppTheme.paddingSmall

                    // Delegado: NotificationHistoryItem (recibe la
                    // notificación como modelData del modelo)
                    delegate: NotificationHistoryItem {
                        width: listView.width
                        height: isExpanded ? expandedHeight : collapsedHeight
                        // isExpanded manejado internamente por el item
                    }

                    // Scrollbar
                    ScrollBar.vertical: ScrollBar {
                        width: 6
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            radius: 3
                            color: Qt.alpha(AppTheme.fg, 0.3)
                        }
                    }
                }

                // ─── Empty State ───
                Loader {
                    id: emptyLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: NotificationsService.unreadCount === 0
                    sourceComponent: emptyComponent
                }
            }

            // ─── IPC Handler ───
            //
            // SUPER+N → `quickshell ipc call notifications toggle`
            IpcHandler {
                target: "notifications"
                function toggle(): void { NotificationsService.notificationCenterOpen = !NotificationsService.notificationCenterOpen }
                function open(): void { NotificationsService.notificationCenterOpen = true }
                function close(): void { NotificationsService.notificationCenterOpen = false }
                function toggleDND(): void { NotificationsService.toggleDND() }
                function clear(): void { NotificationsService.dismissAll() }
            }

            // ─── Empty State Component ───
            Component {
                id: emptyComponent
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "\uf1f6"
                        font.family: AppTheme.fontMono
                        font.pixelSize: 48
                        color: AppTheme.textTertiary
                    }
                    Text {
                        text: "Sin notificaciones"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        color: AppTheme.textSecondary
                    }
                }
            }

            Component.onCompleted: {
                // Auto-focus para navegación por teclado
                // PanelWindow gets focus via WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            }
        }
    }
}