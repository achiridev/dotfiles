import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

import qs.globals
import qs.services
import qs.widgets.notifications

// windows/notifications/NotificationHistoryItem.qml
// Item compacto para el ListView del centro de notificaciones
Item {
    id: item

    // `notification` NO puede ser required: los delegates (ListView/Repeater)
    // inyectan el objeto como `modelData`, y un alias no cuenta como required
    // ("Required property notification was not initialized").
    property var modelData
    property Notification notification: modelData ? modelData : null
    property bool isExpanded: false

    // ──────────────────────────────────────────────────────────────
    // Snapshot de datos.
    //
    // Igual que en el toast: son propiedades PLANAS asignadas una vez en
    // Component.onCompleted, NO bindings. El Notification se destruye al
    // expirarse y un binding que lo lee después lanza
    // "Cannot read property 'x' of null".
    // ──────────────────────────────────────────────────────────────
    property int sId: 0
    property string sAppName: "Desconocido"
    property string sAppIcon: ""
    property string sDesktopEntry: ""
    property string sSummary: "(sin título)"
    property string sBody: ""
    property string sImage: ""
    property bool sResident: false
    property int sUrgency: NotificationUrgency.Normal
    property var sActions: []   // [{ identifier, text }]
    property real sSentAt: 0

    implicitWidth: 460
    implicitHeight: isExpanded ? expandedHeight : collapsedHeight

    readonly property color bgColor: AppTheme.bgPopup
    readonly property color borderColor: AppTheme.borderColor
    readonly property color textColor: AppTheme.fg
    readonly property color textSecondaryColor: AppTheme.textSecondary
    readonly property color urgencyColor: (() => {
        switch (sUrgency) {
            case NotificationUrgency.Critical: return AppTheme.critical;
            case NotificationUrgency.Low:      return AppTheme.warning;
            default:                           return AppTheme.accent;
        }
    })()

    // Las acciones/imagen solo se muestran expandido, así que el alto
    // máximo se calcula con un tope razonable para no crear un item gigante.
    property int collapsedHeight: 72
    // OJO: no derivar esto de content.implicitHeight → los componentes
    // cargados por Loader leen item.width y se produce un binding loop.
    // El alto expandido lo fija el ListView (altura del delegate), no el item.
    property int expandedHeight: Math.min(400, 72 + (sBody ? 90 : 0)
        + (sImage ? 200 : 0) + (sActions.length > 0 ? 32 : 0))

    // Ancho útil del contenido de la tarjeta.
    readonly property int contentWidth: width - 8 - AppTheme.paddingBase * 2

    // Click para expandir/colapsar
    MouseArea {
        anchors.fill: parent
        onClicked: item.isExpanded = !item.isExpanded
    }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 4
        radius: AppTheme.radius
        color: bgColor
        border.width: 1
        border.color: borderColor

        // Línea de urgencia a la izquierda
        Rectangle {
            width: 3
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            radius: AppTheme.radius
            color: item.urgencyColor
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: AppTheme.paddingSmall

            // ─── Header ───
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                // App icon
                Loader {
                    id: iconLoader
                    property string fallbackColor: item.urgencyColor
                    sourceComponent: item.sAppIcon ? iconFromName : (item.sDesktopEntry ? iconFromDesktop : iconFallback)
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }

                // App name + summary
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: item.sAppName
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontTiny
                        color: textSecondaryColor
                        elide: Text.ElideRight
                    }

                    Text {
                        text: item.sSummary
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        font.bold: true
                        color: textColor
                        elide: Text.ElideRight
                        maximumLineCount: isExpanded ? 3 : 1
                    }
                }

                // Time
                Text {
                    text: item.formatWhen()
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontTiny
                    color: textSecondaryColor
                }

                // Expand/collapse chevron
                Text {
                    text: isExpanded ? "\uf077" : "\uf078" // fa-chevron-up/down
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontSmall
                    color: textSecondaryColor
                }

                // Dismiss button
                MouseArea {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationsService.dismiss(item.sId)
                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontSmall
                        color: textSecondaryColor
                    }
                }
            }

            // ─── Body (expandido) ───
            Text {
                id: bodyText
                Layout.fillWidth: true
                visible: item.isExpanded && item.sBody.length > 0
                text: item.sBody
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                color: textColor
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                maximumLineCount: item.isExpanded ? 20 : 0
                onLinkActivated: (url) => Qt.openUrlExternally(url)
            }

            // ─── Image (expandido) ───
            Loader {
                id: imageLoader
                // Los Component se evalúan fuera del árbol: se leen los datos
                // a través de estas propiedades intermedias.
                property string imageSource: item.sImage
                readonly property real compWidth: item.contentWidth
                visible: item.isExpanded && item.sImage.length > 0
                sourceComponent: imageComponent
            }

            // ─── Actions (expandido) ───
            Loader {
                id: actionsLoader
                property var actionList: item.sActions
                readonly property real compWidth: item.contentWidth
                visible: item.isExpanded && item.sActions.length > 0
                sourceComponent: actionsComponent
            }
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Componentes
    // ──────────────────────────────────────────────────────────────
    Component {
        id: iconFromName
        IconImage {
            source: item.sAppIcon
            width: 24; height: 24
        }
    }

    Component {
        id: iconFromDesktop
        IconImage {
            source: Quickshell.iconPath(item.sDesktopEntry)
            width: 24; height: 24
        }
    }

    Component {
        id: iconFallback
        Text {
            text: "\uf0f3"
            font.family: AppTheme.fontMono
            font.pixelSize: AppTheme.fontBase
            color: iconLoader.fallbackColor
        }
    }

    Component {
        id: imageComponent
        Rectangle {
            width: imageLoader.compWidth
            height: 200
            radius: AppTheme.radiusSmall
            clip: true
            color: "transparent"
            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: imageLoader.imageSource
                asynchronous: true
            }
        }
    }

    Component {
        id: actionsComponent
        RowLayout {
            width: actionsLoader.compWidth
            spacing: AppTheme.paddingSmall
            Repeater {
                model: Math.min(actionsLoader.actionList.length, 4)
                delegate: MouseArea {
                    required property int index
                    Layout.preferredHeight: 32
                    Layout.fillWidth: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const a = actionsLoader.actionList[index];
                        if (a) NotificationsService.invokeAction(item.sId, a.identifier);
                        if (!item.sResident) NotificationsService.dismiss(item.sId);
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: AppTheme.radiusSmall
                        color: AppTheme.surface
                        border.width: 1
                        border.color: item.borderColor
                        Text {
                            anchors.centerIn: parent
                            text: actionsLoader.actionList[index]
                                ? actionsLoader.actionList[index].text : ""
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: item.textColor
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────

    // Hora relativa (paridad con swaync relative-timestamps), con el
    // timestamp que el servicio guardó al recibir la notificación.
    function formatWhen() {
        if (!item.sSentAt) return "";
        const diff = Math.max(0, Math.floor((Date.now() - item.sSentAt) / 1000));
        if (diff < 60) return "hace " + diff + " s";
        if (diff < 3600) return "hace " + Math.floor(diff / 60) + " min";
        return Qt.formatTime(new Date(item.sSentAt), "HH:mm");
    }

    // ──────────────────────────────────────────────────────────────
    // Snapshot de datos
    //
    // NO se puede hacer en Component.onCompleted: en los delegates de
    // ListView el objeto se reutiliza (pool) y modelData cambia DESPUÉS
    // de onCompleted, así que el snapshot quedaba vacío.
    //
    // Se usa onModelDataChanged: dispara cuando el delegate recibe su
    // objeto, y el Notification sigue vivo en ese momento.
    // ──────────────────────────────────────────────────────────────
    onModelDataChanged: snapshot()
    Component.onCompleted: snapshot()

    function snapshot() {
        const n = modelData;
        if (!n) return;
        item.sId = n.id;
        item.sAppName = n.appName || "Desconocido";
        item.sAppIcon = n.appIcon;
        item.sDesktopEntry = n.desktopEntry;
        item.sSummary = n.summary || "(sin título)";
        item.sBody = n.body || "";
        item.sImage = n.image || "";
        item.sResident = n.resident;
        item.sUrgency = n.urgency;
        item.sSentAt = NotificationsService.sentAt(n.id);

        const acts = [];
        if (n.actions) {
            for (let i = 0; i < Math.min(4, n.actions.length); ++i) {
                const a = n.actions[i];
                if (a) acts.push({ identifier: a.identifier, text: a.text });
            }
        }
        item.sActions = acts;
    }
}