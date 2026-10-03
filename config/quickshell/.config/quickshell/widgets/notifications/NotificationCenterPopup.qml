import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

import qs.globals
import qs.services
import qs.widgets.notifications

// widgets/notifications/NotificationCenterPopup.qml
// Popup compacto al hacer hover en la campana (estilo VolumePopup)
PopupWindow {
    id: popup

    property Item anchorItem
    property bool requestOpen: false
    property bool shown: false
    readonly property bool hovered: hoverHandler.hovered

    visible: shown

    onRequestOpenChanged: {
        if (requestOpen) {
            closeAnim.stop()
            if (shown) {
                card.opacity = 0
                card.scale = 0.92
                card.y = 8
                openAnim.start()
            } else {
                shown = true
            }
        } else if (shown && !closeAnim.running) {
            closeAnim.start()
        }
    }

    onShownChanged: {
        if (shown) {
            card.opacity = 0
            card.scale = 0.92
            card.y = 8
            openAnim.start()
        }
    }

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? (anchorItem.width / 2 - implicitWidth / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height : 0
    anchor.adjustment: PopupAdjustment.Slide

    implicitWidth: 380
    implicitHeight: card.implicitHeight
    color: "transparent"

    Rectangle {
        id: card
        width: popup.implicitWidth
        implicitHeight: layout.implicitHeight + (AppTheme.paddingLarge + AppTheme.paddingSmall) * 2
        radius: AppTheme.radiusLarge
        color: AppTheme.bgPopup
        border.width: 1
        border.color: AppTheme.borderColor
        transformOrigin: Item.Top

        HoverHandler { id: hoverHandler }

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: AppTheme.paddingLarge + AppTheme.paddingSmall
            spacing: AppTheme.paddingBase

            // ─── Header ───
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                Text {
                    text: "Notificaciones"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontBase
                    font.bold: true
                    color: AppTheme.fg
                }

                Item { Layout.fillWidth: true }

                // DND toggle compacto
                MouseArea {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 28
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationsService.toggleDND()
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: AppTheme.radiusSmall
                        color: NotificationsService.dndEnabled ? AppTheme.critical : AppTheme.surface
                        border.width: 1
                        border.color: NotificationsService.dndEnabled ? AppTheme.critical : AppTheme.borderColor
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: NotificationsService.dndEnabled ? "\uf1f6" : "\uf0f3"
                                font.family: AppTheme.fontMono
                                font.pixelSize: AppTheme.fontSmall
                                color: NotificationsService.dndEnabled ? AppTheme.bg : AppTheme.fg
                            }
                            Text {
                                text: NotificationsService.dndEnabled ? "DND" : "ON"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontTiny
                                color: NotificationsService.dndEnabled ? AppTheme.bg : AppTheme.fg
                            }
                        }
                    }
                }

                // Clear all
                MouseArea {
                    Layout.preferredWidth: 70
                    Layout.preferredHeight: 28
                    cursorShape: Qt.PointingHandCursor
                    enabled: NotificationsService.unreadCount > 0
                    onClicked: NotificationsService.clearHistory()
                    Text {
                        anchors.centerIn: parent
                        text: "\uf0c2"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontSmall
                        color: enabled ? AppTheme.fg : AppTheme.textTertiary
                    }
                }
            }

            // ─── Divider ───
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: AppTheme.borderColor
                opacity: 0.3
            }

            // ─── Lista con scroll ───
            //
            // Flickable + Column + Repeater (NO ListView): con ListView los
            // roles del delegate se asignan después de Component.onCompleted
            // y el cambio de `modelData` no siempre emite su señal, así que
            // el item se quedaba con el snapshot vacío ("Desconocido" /
            // "(sin título)"). Con Repeater la inyección de modelData sí
            // funciona. Flickable aporta el scroll (barra + rueda nativos).
            //
            // El alto visible está acotado a ~5 items: el resto se alcanza
            // con la rueda o arrastrando la barra.
            Flickable {
                id: scrollArea
                Layout.fillWidth: true
                Layout.preferredHeight: {
                    const visible = Math.min(NotificationsService.unreadCount,
                                              AppTheme.notificationsHistoryMaxVisible);
                    if (visible <= 0) return 0;
                    return visible * (AppTheme.notificationsHistoryRowHeight
                                      + AppTheme.paddingSmall) - AppTheme.paddingSmall;
                }
                Layout.minimumHeight: 0
                visible: NotificationsService.unreadCount > 0

                contentWidth: width
                contentHeight: recentColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: recentColumn
                    width: scrollArea.width
                    spacing: AppTheme.paddingSmall

                    // La notificación se pasa EXPLÍCITAMENTE por índice en lugar de
                    // confiar en el rol `modelData`: con este Repeater el rol
                    // llegaba `undefined` (el item se quedaba con su snapshot
                    // vacío: "Desconocido" / "(sin título)"), y en un ListView
                    // Qt asigna los roles después de Component.onCompleted sin
                    // que el cambio de modelData emita su señal. Indexando el
                    // array directamente no depende de nada de eso.
                    Repeater {
                        model: NotificationsService.historyNewestFirst
                        delegate: NotificationHistoryItem {
                            required property int index
                            width: recentColumn.width
                            height: isExpanded ? expandedHeight : collapsedHeight
                            notification: NotificationsService.historyNewestFirst[index]
                        }
                    }
                }

                // Barra de scroll: solo si hay más items que los visibles
                ScrollBar.vertical: ScrollBar {
                    width: 6
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        radius: 3
                        color: Qt.alpha(AppTheme.fg, 0.3)
                    }
                }
            }

            // ─── Empty state ───
            Loader {
                id: emptyLoader
                visible: NotificationsService.unreadCount === 0
                sourceComponent: emptyComponent
            }
        }
    }

    Component {
        id: emptyComponent
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            spacing: AppTheme.paddingSmall

            Text {
                text: "\uf1f6"
                font.family: AppTheme.fontMono
                font.pixelSize: 32
                color: AppTheme.textTertiary
            }
            Text {
                text: "Sin notificaciones"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                color: AppTheme.textSecondary
            }
        }
    }

    // ─── IPC ───
    //
    // Este handler vivía en la ventana del centro (que se eliminó). Vive
    // aquí porque el popup está siempre montado dentro de la campana, así
    // que el target "notifications" sigue respondiendo:
    //   quickshell ipc call notifications toggleDND
    //   quickshell ipc call notifications clear
    IpcHandler {
        target: "notifications"
        function toggleDND(): void { NotificationsService.toggleDND() }
        function clear(): void { NotificationsService.clearHistory() }
        // Solo lectura, para depurar sin necesidad del ratón:
        //   quickshell ipc call notifications status
        function status(): string {
            return JSON.stringify({
                unread: NotificationsService.unreadCount,
                dnd: NotificationsService.dndEnabled,
                themes: NotificationThemes.allowed
            })
        }
    }

    // ─── Animaciones (idénticas a VolumePopup) ───
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; to: 1;    duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale";   to: 1;    duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "y";       to: 0;    duration: 180; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: card; property: "opacity"; to: 0;    duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "scale";   to: 0.95; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "y";       to: 6;    duration: 140; easing.type: Easing.InCubic }
        onFinished: popup.shown = false
    }
}