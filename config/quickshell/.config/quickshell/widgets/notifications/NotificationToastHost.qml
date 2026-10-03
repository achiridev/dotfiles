import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

import qs.globals
import qs.services
import qs.widgets.notifications

// widgets/notifications/NotificationToastHost.qml
// Host per-monitor de toasts: un PanelWindow chico anclado al top-right de
// cada monitor (layer Overlay, exclusiveZone 0 para no empujar ventanas).
// Los toasts se apilan en un Column; máx. 3 visibles (AppTheme.notificationsToastMaxVisible).
Scope {
    id: host

    Variants {
        id: variants
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: toastContainer
                required property var modelData

                screen: modelData
                visible: true

                exclusiveZone: 0
                WlrLayershell.namespace: "quickshell:toasts"
                WlrLayershell.layer: WlrLayer.Overlay

                // Top-right del monitor. Layer-shell no soporta márgenes de
                // anclaje, así que la ventana es un poco más grande que el
                // stack y el Column se offsetea con Qt anchors (la zona
                // transparente deja ver la barra y el escritorio).
                anchors {
                    top: true
                    right: true
                }

                implicitWidth: 420 + AppTheme.paddingLarge + 12
                implicitHeight: AppTheme.heightBar + 12 + toastColumn.implicitHeight
                color: "transparent"

                Column {
                    id: toastColumn
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: AppTheme.heightBar + 12
                    anchors.rightMargin: AppTheme.paddingLarge + 12
                    spacing: AppTheme.notificationsToastGap

                    property var toastStack: []

                    // Escuchar al SERVICIO (no al server): así llegan solo las
                // notificaciones que pasaron los filtros (no tragadas por las
                // reglas de paridad, no transientes, no bloqueadas por DND).
                Connections {
                    target: NotificationsService
                    function onNotificationReceived(notification) {
                        toastColumn.addToast(notification);
                    }
                }

                function addToast(notification) {
                    // Tras un restart, keepOnReload re-emite el historial:
                    // alimenta el centro, pero no debe repintar toasts.
                    if (notification.lastGeneration) return;

                    // Verificar duplicados (por sId: el Notification puede
                    // estar ya destruido si cerró mientras el toast sale)
                    for (let i = 0; i < toastColumn.toastStack.length; ++i) {
                        if (toastColumn.toastStack[i].sId === notification.id) return;
                    }

                        const component = Qt.createComponent("NotificationToastItem.qml");
                        if (component.status !== Component.Ready) {
                            console.warn("NotificationToastItem component not ready:", component.errorString());
                            return;
                        }

                        const toastObj = component.createObject(toastColumn, {
                            "notification": notification,
                            "index": toastColumn.toastStack.length,
                            "maxVisible": AppTheme.notificationsToastMaxVisible
                        });

                        if (toastObj) {
                            toastColumn.toastStack.push(toastObj);
                            limitStack();
                        }
                    }

                    function removeToast(toastObj) {
                        const idx = toastColumn.toastStack.indexOf(toastObj);
                        if (idx >= 0) {
                            toastColumn.toastStack.splice(idx, 1);
                        }
                    }

                    function limitStack() {
                        while (toastColumn.toastStack.length > AppTheme.notificationsToastMaxVisible) {
                            const old = toastColumn.toastStack.shift();
                            if (old) old.dismiss();
                        }
                    }

                    Component.onDestruction: {
                        for (let i = 0; i < toastColumn.toastStack.length; ++i) {
                            if (toastColumn.toastStack[i]) toastColumn.toastStack[i].destroy();
                        }
                        toastColumn.toastStack = [];
                    }
                }
            }
        }
    }
}
