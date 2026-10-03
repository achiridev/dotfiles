import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

import qs.globals
import qs.services

// widgets/notifications/NotificationToastItem.qml
// Item individual de toast (vive en el Column del NotificationToastHost).
//
// Ciclo de vida: el objeto Notification puede destruirse cuando se expira /
// se descarta / se invoca una acción, así que al crearse se toman SNAPSHOT
// de los datos en propiedades planas y el cierre se detecta con el signal
// `closed` del Notification (no con referencias a sus propiedades).
Item {
    id: toast

    required property Notification notification
    required property int index
    required property int maxVisible

    property bool shown: false
    property bool closing: false
    property bool hovered: false
    property real progress: 1.0

    // ──────────────────────────────────────────────────────────────
    // Snapshot de datos
    //
    // Son propiedades PLANAS, asignadas una sola vez en Component.onCompleted
    // (NO bindings): el objeto Notification se destruye al cerrarse y un
    // binding que lo lee después falla con
    // "Cannot read property 'x' of null".
    // ──────────────────────────────────────────────────────────────
    property string sSummary: "Notificación"
    property string sAppName: ""
    property string sAppIcon: ""
    property string sDesktopEntry: ""
    property string sBody: ""
    property string sImage: ""
    property bool sHasInlineReply: false
    property string sInlinePlaceholder: "Responder..."
    property bool sResident: false
    property var sActions: []
    property int sUrgency: NotificationUrgency.Normal

    // Id: clave con la que el servicio guarda el estado de expiración.
    // Tras la destrucción del Notification sigue siendo válido para consultar
    // progreso/hora y para pausar/reanudar el timer real.
    property int sId: 0

    // ──────────────────────────────────────────────────────────────
    // Tema (opcional)
    //
    // Lo resuelve el registro NotificationThemes por appName. Si la
    // notificación no tiene tema, `theme` es null y todo lo de abajo cae
    // al comportamiento normal. Ver themes/README.md.
    // ──────────────────────────────────────────────────────────────
    property var theme: null

    // ¿Hay tema? Marca el camino de color de acento y timeout.
    readonly property bool hasTheme: toast.theme !== null

    // Color de acento: el del tema si existe, si no el de la urgencia.
    readonly property color accentColor: toast.hasTheme
        ? toast.theme.accent
        : toast.urgencyColor

    // Título/cuerpo: los del tema si la notificación no los trajo.
    readonly property string displaySummary: toast.sSummary
        || (toast.hasTheme ? toast.theme.defaultSummary : "Notificación")
    readonly property string displayBody: toast.sBody
        || (toast.hasTheme ? toast.theme.defaultBody : "")

    // Icono: el del tema si existe.
    readonly property string displayIcon: toast.sAppIcon
        || (toast.hasTheme && toast.theme.icon ? toast.theme.icon : "")

    // Glifo de fuente del tema (p. ej. batería).
    //
    // Va aparte de displayIcon a propósito: displayIcon se resuelve con
    // Quickshell.iconPath(), que busca un ARCHIVO con ese nombre. Un glifo
    // de fuente (U+F240) no existe como archivo, así que por ahí salía un
    // tofu y el aviso "Could not load icon". Los glifos van como Text con
    // AppTheme.fontMono, que es como la barra ya pinta la campana (U+F0F3).
    readonly property string themeGlyph: (toast.hasTheme && toast.theme.glyph)
        ? toast.theme.glyph : ""

    // El tema puede querer su propio medidor (barra de nivel de batería).
    readonly property bool showGauge: toast.hasTheme && toast.theme.showGauge
    readonly property real gaugeValue: toast.hasTheme ? toast.theme.gaugeValue : 0

    // Hora de envío en ms epoch (la pinta el servicio al recibirla) para la
    // hora relativa. OJO: debe ser real, no int — un timestamp en ms (~1.7e12)
    // desborda el int de 32 bits (~2.1e9) y daría un valor corrupto.
    property real sSentAt: 0

    function resolveIcon() {
        if (toast.displayIcon) {
            if (toast.displayIcon.startsWith("file:") || toast.displayIcon.startsWith("/"))
                return toast.displayIcon;
            const t = Quickshell.iconPath(toast.displayIcon);
            if (t) return t;
        }
        if (toast.sAppIcon) {
            if (toast.sAppIcon.startsWith("file:") || toast.sAppIcon.startsWith("/"))
                return toast.sAppIcon;
            const p = Quickshell.iconPath(toast.sAppIcon);
            if (p) return p;
        }
        if (toast.sDesktopEntry) {
            const p = Quickshell.iconPath(toast.sDesktopEntry);
            if (p) return p;
        }
        return "";
    }
    readonly property string iconSource: resolveIcon()

    readonly property color urgencyColor: (() => {
        switch (toast.sUrgency) {
            case NotificationUrgency.Critical: return AppTheme.critical;
            case NotificationUrgency.Low:      return AppTheme.warning;
            default:                           return AppTheme.accent;
        }
    })()

    readonly property color bgColor: AppTheme.bgPopup
    readonly property color borderColor: AppTheme.borderColor
    readonly property color textColor: AppTheme.fg
    readonly property color textSecondaryColor: AppTheme.textSecondary

    width: AppTheme.notificationsToastWidth
    implicitHeight: card.implicitHeight

    // Ancho útil del contenido: el Cardinner deja márgenes
    // (AppTheme.paddingLarge + AppTheme.paddingSmall) a cada lado.
    // Necesario porque los items cargados por Loader ya no son hijos
    // directos del ColumnLayout y los Layout.* no se aplican a ellos.
    readonly property int contentWidth:
        width - (AppTheme.paddingLarge + AppTheme.paddingSmall) * 2

    // Timeout efectivo (paridad con el servicio: normal 8s, low 5s, critical
    // nunca). Se congela al crear el toast con el valor del servicio.
    readonly property int effectiveTimeoutMs: toast.totalMs

    readonly property bool hasAutoExpire: toast.totalMs > 0

    // Cuenta atrás propia del toast.
    //
    // El toast NO puede depender solo de la señal `closed` del Notification:
    // las transient no se trackean, así que Quickshell destruye el objeto
    // nada más salir del handler y esa señal nunca llega (el toast se
    // quedaría colgado para siempre). Con este reloj el toast se cierra
    // solo siempre, esté trackeado o no.
    property int totalMs: 0
    property real deadline: 0
    property real frozen: 0

    function formatWhen() {
        if (!toast.sSentAt) return Qt.formatTime(new Date(), "HH:mm");
        const diff = Math.max(0, Math.floor((Date.now() - toast.sSentAt) / 1000));
        if (diff < 60) return "hace " + diff + " s";
        if (diff < 3600) return "hace " + Math.floor(diff / 60) + " min";
        return Qt.formatTime(new Date(toast.sSentAt), "HH:mm");
    }
    // Tick para refrescar la hora relativa (estilo swaync relative-timestamps)
    property int tick: 0
    Timer {
        interval: 10000
        repeat: true
        running: !toast.closing
        onTriggered: toast.tick++
    }

    // ──────────────────────────────────────────────────────────────
    // Cierre cuando el Notification se cierra (expire/dismiss/action)
    // ──────────────────────────────────────────────────────────────
    Connections {
        target: toast.notification
        function onClosed(reason) { toast.dismiss(); }
    }

    // ──────────────────────────────────────────────────────────────
    // Animaciones
    // ──────────────────────────────────────────────────────────────
    SequentialAnimation {
        id: openAnim
        running: false
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "y"; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: closeAnim
        running: false
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "scale"; to: 0.95; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "y"; to: 6; duration: 140; easing.type: Easing.InCubic }
        onFinished: {
            toast.shown = false;
            toast.closing = true;
            toast.destroy();
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Tarjeta principal
    // ──────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        width: toast.width
        implicitHeight: contentColumn.implicitHeight + (AppTheme.paddingLarge + AppTheme.paddingSmall) * 2
        radius: AppTheme.radiusLarge
        color: toast.bgColor
        border.width: 1
        border.color: toast.borderColor
        transformOrigin: Item.Top
        opacity: 0
        scale: 0.92
        y: 8

        // Línea de acento por urgencia
        Rectangle {
            id: urgencyLine
            width: parent.width
            height: 3
            color: toast.accentColor
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Hover: congela la cuenta atrás del toast Y pausa la expiración en el
        // servicio (si la notificación está en el historial, para que no
        // desaparezca del centro mientras se lee).
        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                toast.hovered = hoverHandler.hovered;
                if (hoverHandler.hovered) {
                    toast.frozen = Math.max(0, toast.deadline - Date.now());
                    NotificationsService.pauseExpire(toast.sId);
                } else {
                    toast.deadline = Date.now() + toast.frozen;
                    NotificationsService.resumeExpire(toast.sId);
                }
            }
        }

        // Click / swipe para descartar
        property real _dragStartX: 0
        property bool _dragging: false

        MouseArea {
            id: dragArea
            anchors.fill: parent
            onClicked: dismiss()
            onPressed: {
                if (!closing) {
                    _dragStartX = mouseX;
                    _dragging = true;
                }
            }
            onMouseXChanged: {
                if (_dragging && !closing) {
                    const dx = mouseX - _dragStartX;
                    card.x = dx;
                    card.opacity = Math.max(0.3, 1 - Math.abs(dx) / 200);
                }
            }
            onReleased: {
                if (_dragging) {
                    _dragging = false;
                    const dx = mouseX - _dragStartX;
                    if (Math.abs(dx) > 80) {
                        dismiss();
                    } else {
                        card.x = 0;
                        card.opacity = 1;
                    }
                }
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: AppTheme.paddingLarge + AppTheme.paddingSmall
            spacing: AppTheme.paddingBase

            // Header: icono + summary + hora relativa + close
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                Loader {
                    id: appIconLoader
                    sourceComponent: toast.themeGlyph ? glyphComponent
                                  : (toast.iconSource ? iconComponent : iconFallback)
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }

                Text {
                    id: summaryText
                    Layout.fillWidth: true
                    text: toast.displaySummary
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontBase
                    font.bold: true
                    color: toast.textColor
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    id: timeText
                    text: { toast.tick; return toast.formatWhen(); }
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontTiny
                    color: toast.textSecondaryColor
                }

                MouseArea {
                    id: closeBtn
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dismiss()
                    Rectangle {
                        id: closeBtnBg
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: AppTheme.radiusSmall
                        color: "transparent"
                        border.width: 1
                        border.color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"
                            font.family: AppTheme.fontMono
                            font.pixelSize: AppTheme.fontSmall
                            color: toast.textSecondaryColor
                        }
                    }
                    // parent dentro del handler es el MouseArea → id propio.
                    onEntered: { closeBtnBg.color = AppTheme.surface; closeBtnBg.border.color = AppTheme.borderColor; }
                    onExited: { closeBtnBg.color = "transparent"; closeBtnBg.border.color = "transparent"; }
                }
            }

            // Body (markup)
            Text {
                id: bodyText
                Layout.fillWidth: true
                visible: toast.displayBody && toast.displayBody.length > 0
                text: toast.displayBody
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                color: toast.textColor
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                maximumLineCount: 10
                onLinkActivated: (url) => Qt.openUrlExternally(url)
            }

            // Medidor del tema (p. ej. barra de nivel de batería).
            // Solo visible si el tema lo pide (showGauge).
            Loader {
                id: gaugeLoader
                visible: toast.showGauge
                sourceComponent: gaugeComponent
            }

            // Imagen adjunta
            Loader {
                id: imageLoader
                visible: toast.sImage && toast.sImage.length > 0
                sourceComponent: imageComponent
            }

            // Acciones
            Loader {
                id: actionsLoader
                visible: toast.sActions.length > 0
                sourceComponent: actionsComponent
            }

            // Inline reply
            Loader {
                id: replyLoader
                visible: toast.sHasInlineReply
                sourceComponent: replyComponent
            }

            // Barra de progreso (timeout)
            Rectangle {
                id: progressBar
                Layout.fillWidth: true
                height: 3
                radius: 1.5
                color: Qt.alpha(toast.accentColor, 0.3)
                visible: toast.hasAutoExpire && !toast.closing
                Rectangle {
                    id: progressFill
                    height: parent.height
                    width: parent.width * toast.progress
                    radius: 1.5
                    color: toast.accentColor
                    Behavior on width { NumberAnimation { duration: 100 } }
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Componentes dinámicos
    // ──────────────────────────────────────────────────────────────
    Component {
        id: iconComponent
        IconImage {
            source: toast.iconSource
            width: 24; height: 24
        }
    }

    // Glifo del tema, pintado como texto con la fuente de la barra
    // (AppTheme.fontMono → JetBrainsMono Nerd Font, que sí trae los
    // glifos de Font Awesome en el rango U+F0xx).
    Component {
        id: glyphComponent
        Text {
            text: toast.themeGlyph
            font.family: AppTheme.fontMono
            font.pixelSize: AppTheme.fontBase
            color: toast.accentColor
        }
    }

    Component {
        id: iconFallback
        Text {
            text: "\uf0f3"
            font.family: AppTheme.fontMono
            font.pixelSize: AppTheme.fontBase
            color: toast.urgencyColor
        }
    }

    // Medidor del tema. ancho explícito: los items cargados por Loader
    // no son hijos directos del ColumnLayout, así que Layout.* no aplican.
    Component {
        id: gaugeComponent
        Rectangle {
            width: toast.contentWidth
            height: 8
            radius: 4
            color: Qt.alpha(toast.accentColor, 0.22)
            Rectangle {
                id: gaugeFill
                height: parent.height
                width: parent.width * Math.max(0.02, Math.min(1, toast.gaugeValue))
                radius: parent.radius
                color: toast.accentColor
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    Component {
        id: imageComponent
        Rectangle {
            width: toast.contentWidth
            height: 150
            radius: AppTheme.radius
            clip: true
            color: "transparent"
            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: toast.sImage
                asynchronous: true
            }
        }
    }

    Component {
        id: actionsComponent
        RowLayout {
            width: toast.contentWidth
            spacing: AppTheme.paddingSmall
            Repeater {
                model: toast.sActions.length
                delegate: MouseArea {
                    id: actionBtn
                    required property int index
                    Layout.preferredHeight: 32
                    Layout.fillWidth: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const action = toast.sActions[index];
                        if (action) NotificationsService.invokeAction(toast.sId, action.identifier);
                        if (!toast.sResident) toast.dismiss();
                    }
                    Rectangle {
                        id: actionBg
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: AppTheme.radiusSmall
                        color: AppTheme.surface
                        border.width: 1
                        border.color: toast.borderColor
                        Text {
                            anchors.centerIn: parent
                            text: toast.sActions[index] ? toast.sActions[index].text : ""
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: toast.textColor
                            elide: Text.ElideRight
                        }
                    }
                    // Hover: se resalta el botón (parent aquí es el MouseArea,
                    // por eso el Rectangle necesita id propio).
                    onEntered: actionBg.color = AppTheme.bgModuleHover
                    onExited: actionBg.color = AppTheme.surface
                }
            }
        }
    }

    Component {
        id: replyComponent
        RowLayout {
            width: toast.contentWidth
            spacing: AppTheme.paddingSmall
            TextField {
                id: replyField
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                placeholderText: toast.sInlinePlaceholder
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                color: toast.textColor
                background: Rectangle {
                    radius: AppTheme.radiusSmall
                    color: Qt.alpha(AppTheme.bg, 0.5)
                    border.width: 1
                    border.color: toast.borderColor
                }
                Keys.onReturnPressed: toast.sendReply()
            }
            MouseArea {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 36
                cursorShape: Qt.PointingHandCursor
                onClicked: toast.sendReply()
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: AppTheme.radiusSmall
                    color: toast.urgencyColor
                    Text {
                        anchors.centerIn: parent
                        text: "\uf1d8"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.bg
                    }
                }
            }
        }
    }

    // Inline reply: va por el servicio (NotificationsService.byId) para no
    // tocar un Notification ya destruido.
    function sendReply() {
        if (!replyField) return;
        const text = replyField.text.trim();
        if (text.length === 0) return;
        const n = NotificationsService.byId(toast.sId);
        if (!n) return;
        n.sendInlineReply(text);
        if (!toast.sResident) toast.dismiss();
    }

    // ──────────────────────────────────────────────────────────────
    // Lifecycle
    // ──────────────────────────────────────────────────────────────
    Component.onCompleted: {
        // ── Snapshot de TODOS los datos de la notificación ──
        // Se hace aquí y no como binding porque el objeto Notification se
        // destruye al cerrarse: leer sus propiedades después lanza
        // "Cannot read property 'x' of null".
        const n = notification;
        if (!n) { destroy(); return; }

        toast.sId = n.id;
        toast.sAppName = n.appName;

        // Resolver tema por appName ANTES de leer summary/body/icon, porque
        // el tema puede aportarlos si la notificación no los trajo.
        toast.theme = NotificationThemes.resolve(n.appName);

        toast.sSummary = n.summary
            || (toast.hasTheme ? toast.theme.defaultSummary : "");
        toast.sAppIcon = n.appIcon;
        toast.sDesktopEntry = n.desktopEntry;
        toast.sBody = n.body;
        toast.sImage = n.image;
        toast.sHasInlineReply = n.hasInlineReply;
        toast.sInlinePlaceholder = n.inlineReplyPlaceholder || "Responder...";
        toast.sResident = n.resident;
        toast.sUrgency = n.urgency;
        toast.sSentAt = NotificationsService.sentAt(n.id);

        // Las acciones se copian a objetos planos (identifier + text): los
        // NotificationAction son objetos vivos que mueren con la notificación.
        const acts = [];
        if (n.actions) {
            for (let i = 0; i < Math.min(3, n.actions.length); ++i) {
                const a = n.actions[i];
                if (a) acts.push({ identifier: a.identifier, text: a.text });
            }
        }
        toast.sActions = acts;

        // Cuenta atrás propia (paridad con el servicio: normal 8s, low 5s,
        // critical nunca). Se congela aquí para que el toast sea autónomo.
        // Un TEMA puede mandar su propio timeout (p. ej. batería baja = 0,
        // no expira nunca). Sin tema, el del servicio.
        toast.totalMs = toast.hasTheme ? toast.theme.timeoutMs
                                       : NotificationsService.timeoutFor(n);
        toast.deadline = Date.now() + toast.totalMs;
        toast.frozen = toast.totalMs;
        toast.progress = toast.totalMs > 0 ? 1 : 0;

        shown = true;
        openAnim.start();
    }

    // Cuenta atrás + barra de progreso. Se detiene con el hover.
    Timer {
        id: countdown
        interval: 100
        repeat: true
        running: toast.hasAutoExpire && !toast.closing && !toast.hovered
        onTriggered: {
            const left = toast.deadline - Date.now();
            toast.progress = Math.max(0, Math.min(1, left / toast.totalMs));
            if (left <= 0) toast.dismiss();
        }
    }

    function dismiss() {
        if (toast.closing) return;
        toast.closing = true;
        closeAnim.start();
        const host = toast.parent;
        if (host && host.removeToast) host.removeToast(toast);
    }
}
