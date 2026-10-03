import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

import qs.globals
import qs.services

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

            // ─── Lista compacta (máx 5 items) ───
            ColumnLayout {
                id: recentList
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    // historyModel es una lista plana (values del modelo del
                    // server), así que el Repeater ya inyecta modelData.
                    model: Math.min(NotificationsService.unreadCount, 5)
                    delegate: NotificationHistoryItem {
                        width: recentList.width
                        isExpanded: false
                        Layout.fillWidth: true
                    }
                }

                // "Ver más" si hay más de 5
                Loader {
                    id: moreLoader
                    visible: NotificationsService.unreadCount > 5
                    sourceComponent: moreComponent
                }
            }

            // ─── Empty state ───
            Loader {
                id: emptyLoader
                visible: NotificationsService.unreadCount === 0
                sourceComponent: emptyComponent
            }

            // ─── Footer: abrir centro completo ───
            MouseArea {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    NotificationsService.notificationCenterOpen = true;
                    popup.requestOpen = false;
                }
                Rectangle {
                    id: openCenterBg
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: AppTheme.radiusSmall
                    color: AppTheme.surface
                    border.width: 1
                    border.color: AppTheme.borderColor
                    Text {
                        anchors.centerIn: parent
                        text: "\uf05a  Abrir centro de notificaciones"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.fg
                    }
                }
                // parent en el handler es el MouseArea → id propio en el Rectangle.
                onEntered: openCenterBg.color = AppTheme.bgModuleHover
                onExited: openCenterBg.color = AppTheme.surface
            }
        }
    }

    Component {
        id: moreComponent
        MouseArea {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                NotificationsService.notificationCenterOpen = true;
                popup.requestOpen = false;
            }
            Text {
                anchors.centerIn: parent
                text: "+ " + (NotificationsService.unreadCount - 5) + " más..."
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                color: AppTheme.textSecondary
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