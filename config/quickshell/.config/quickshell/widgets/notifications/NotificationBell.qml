import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs.globals
import qs.services

// widgets/notifications/NotificationBell.qml
// Widget de barra: campana con badge + click abre centro, hover abre popup compacto
Item {
    id: root

    implicitWidth: box.implicitWidth
    implicitHeight: AppTheme.heightBar

    property bool popupOpen: false

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool shouldOpen: hovered || popup.hovered

    onShouldOpenChanged: {
        if (root.shouldOpen) {
            closeTimer.stop()
            root.popupOpen = true
        } else {
            closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: 150
        onTriggered: root.popupOpen = false
    }

    HoverHandler { id: hoverHandler }

    Rectangle {
        id: box
        anchors.fill: parent
        implicitWidth: content.implicitWidth + AppTheme.paddingBase * 2
        radius: AppTheme.radius
        border.width: 1
        border.color: AppTheme.borderColor
        color: root.hovered ? AppTheme.bgModuleHover : AppTheme.bgModule
        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

        RowLayout {
            id: content
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: 4

            // Icono campana
            Text {
                id: bellIcon
                text: NotificationsService.dndEnabled ? "\uf1f6" : "\uf0f3" // bell-slash / bell
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                color: NotificationsService.dndEnabled ? AppTheme.critical : AppTheme.fg
                Layout.alignment: Qt.AlignVCenter
            }

            // Badge contador
            Loader {
                id: badgeLoader
                visible: NotificationsService.unreadCount > 0
                sourceComponent: badgeComponent
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                NotificationsService.notificationCenterOpen = !NotificationsService.notificationCenterOpen;
            } else if (mouse.button === Qt.RightButton) {
                NotificationsService.toggleDND();
            } else if (mouse.button === Qt.MiddleButton) {
                NotificationsService.clearHistory();
            }
        }
        onWheel: (wheel) => {
            // Scroll en campana: próximo/prev notificación (futuro)
        }
    }

    // ─── Badge component ───
    Component {
        id: badgeComponent
        Rectangle {
            id: badge
            Layout.preferredHeight: 18
            Layout.minimumWidth: 18
            radius: 9
            color: AppTheme.critical
            border.width: 1
            border.color: AppTheme.bgPopup
            property string countText: NotificationsService.unreadCount > 9 ? "9+" : NotificationsService.unreadCount
            Text {
                anchors.centerIn: parent
                text: countText
                font.family: AppTheme.fontLayout
                font.pixelSize: 10
                font.bold: true
                color: AppTheme.bg
                padding: 0
            }
            Behavior on Layout.minimumWidth { NumberAnimation { duration: 150 } }
        }
    }

    // ─── Popup compacto (hover) ───
    NotificationCenterPopup {
        id: popup
        anchorItem: root
        requestOpen: root.popupOpen
        visible: root.popupOpen || popup.hovered
    }
}