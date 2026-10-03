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
            // `anchors.centerIn` y NO `anchors.fill` + `anchors.margins`.
            //
            // La barra mide AppTheme.heightBar (30px). Con márgenes de
            // paddingBase (8px) el RowLayout solo recibía 14px de alto
            // mientras sus hijos necesitan ~17px (texto) y 18px (badge):
            // el layout comprimía el Text, que con verticalAlignment por
            // defecto (AlignTop) pinta el glifo desde arriba de una caja
            // recortada → la campana quedaba ~2px baja.
            //
            // CenterIn deja que la fila tome su altura natural y se centre.
            // El padding horizontal se mantiene igual, porque
            // box.implicitWidth sigue siendo content.implicitWidth + 2*margen.
            //
            // Es el mismo patrón que usan Battery (Row) y SystemStats
            // (RowLayout), que están centrados correctamente.
            anchors.centerIn: parent
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
            // Click izquierdo: sin acción. La interfaz es el popup de hover,
            // así que abrir aquí una ventana solo estorbaría.
            if (mouse.button === Qt.RightButton) {
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
            // OJO: width/height explícitos, NO Layout.preferredHeight.
            // Este Rectangle es hijo del Loader, no del RowLayout, así que
            // los attached properties de Layout no se aplicarían y el badge
            // se quedaría con tamaño 0 (invisible).
            readonly property int textWidth: countText.length > 1 ? 16 : 10
            width: Math.max(18, 10 + textWidth)
            height: 18
            radius: 9
            color: AppTheme.critical
            border.width: 1
            border.color: AppTheme.bgPopup
            property string countText: NotificationsService.unreadCount > 9 ? "9+" : NotificationsService.unreadCount
            Text {
                anchors.centerIn: parent
                text: badge.countText
                font.family: AppTheme.fontLayout
                font.pixelSize: 10
                font.bold: true
                color: AppTheme.bg
                padding: 0
            }
            Behavior on width { NumberAnimation { duration: 150 } }
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