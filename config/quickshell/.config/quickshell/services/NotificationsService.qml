// services/NotificationsService.qml
// Daemon de notificaciones Quickshell (reemplaza a swaync).
// - Notifica vía org.freedesktop.Notifications (libnotify/notify-send/apps).
// - Mantiene el historial del centro de notificaciones.
// - Reproduce las reglas del viejo swaync config.json:
//     * scripts "exec" (tragar notificaciones): Bateria / BateriaAlta / aviso de bloqueo
//     * timeout por urgencia: normal 8s, low 5s, critical nunca
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import qs.globals

Singleton {
    id: root

    // ──────────────────────────────────────────────────────────────
    // Filtros de paridad con swaync (config.json → "scripts" exec:true)
    // Estas notificaciones son "tragadas": ni toast ni historial.
    // - "Bateria"/"BateriaAlta": el script notificacion_bateria.sh ya
    //   reproduce sonido con paplay, no hace falta notificación.
    // - Aviso pre-bloqueo de hypridle (low, "Inactividad detectada").
    // ──────────────────────────────────────────────────────────────
    function isSwallowed(notification) {
        if (notification.appName === "Bateria" || notification.appName === "BateriaAlta")
            return true;
        if (notification.urgency === NotificationUrgency.Low
            && notification.summary.indexOf("Inactividad detectada") >= 0)
            return true;
        return false;
    }

    // Timeout efectivo en ms. Lo mandan los apps vía D-Bus (expireTimeout en
    // SEGUNDOS, -1 = sin expiración, lo que hace notify-send por defecto).
    // Paridad con swaync: normal 8s, low 5s, critical nunca (timeout 0).
    function effectiveTimeoutMs(notification) {
        if (notification.urgency === NotificationUrgency.Critical) return 0; // persiste
        if (notification.expireTimeout > 0) return notification.expireTimeout * 1000;
        if (notification.urgency === NotificationUrgency.Low)
            return AppTheme.notificationsTimeoutLow * 1000;
        return AppTheme.notificationsTimeoutNormal * 1000;
    }

    // ──────────────────────────────────────────────────────────────
    // NotificationServer — el demonio D-Bus real
    // ──────────────────────────────────────────────────────────────
    NotificationServer {
        id: server

        // Capabilities anunciadas a los clientes (libnotify, etc.)
        actionsSupported: true
        inlineReplySupported: true
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionIconsSupported: true

        // Historial trackeado (solo notificaciones con tracked = true)
        readonly property var model: server.trackedNotifications

        // ──────────────────────────────────────────────────────────
        // Manejo de notificaciones entrantes
        // ──────────────────────────────────────────────────────────
        onNotification: (notification) => {
            // 1) Tragadas por regla de paridad con swaync: ni toast ni
            //    historial (el script ya reproduce su propio sonido).
            if (root.isSwallowed(notification)) {
                notification.tracked = false;
                return;
            }

            const isTransient = notification.transient;

            // 2) Do Not Disturb: NO se muestra toast, pero la notificación se guarda
            //    en el centro. Antes se destruía y se perdía para siempre.
            //    La urgency critical siempre se muestra.
            const blockedByDnd = root.dndEnabled
                && notification.urgency !== NotificationUrgency.Critical;

            // 3) Solo entra al historial (modelo) lo que debe persistir.
            //    - un transient NO se guarda (pero sí se muestra como toast):
            //      los OSD de volumen/brillo no deben llenar el centro.
            //    - lo bloqueado por DND SÍ se guarda: solo se le calla el
            //      toast, así no se pierde nada.
            //    Untracked = Quickshell destruye el objeto al salir del
            //    handler, así que ese toast debe vivir de su snapshot.
            const tracked = !isTransient;
            notification.tracked = tracked;

            // Estado del timer de expiración, keyeado por id.
            // (El objeto Notification se destruye al cerrarse, así que el
            // estado vive aquí, no en el propio notification.)
            // El barrido (Timer del servicio) se encarga de expirar.
            const ms = root.effectiveTimeoutMs(notification);
            root._expire[notification.id] = {
                total: ms,
                started: Date.now(),
                paused: false,
                remaining: 0,
                history: tracked
            };

            // Límite de historial: se expira la más antigua (no la que llega)
            root.enforceHistoryLimit();

            // Señal para UI (toast, badge, etc.).
            // DND bloquea el toast, pero no el historial.
            if (!blockedByDnd)
                root.notificationReceived(notification);
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Reactividad del modelo
    //
    // trackedNotifications actualiza de forma DIFERIDA respecto a
    // `tracked = true`: leer `.values` dentro de onNotification devuelve
    // todavía la lista vieja (por eso unreadCount daba 0 y el badge de la
    // campana nunca aparecía). Aquí se sincroniza con las señales reales
    // del modelo, que es cuando la lista ya está al día.
    // ──────────────────────────────────────────────────────────────
    Connections {
        target: server.trackedNotifications
        function onObjectInsertedPost(object, index) {
            root.syncHistoryModel();
            root.pruneExpire();
        }
        function onObjectRemovedPost(object, index) {
            root.syncHistoryModel();
            root.pruneExpire();
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Estado y API pública
    // ──────────────────────────────────────────────────────────────
    property bool dndEnabled: false
    property int historyLimit: 100

    // Signal para que toasts reaccionen
    signal notificationReceived(var notification)

    // API
    function dismiss(id) {
        const n = root.byId(id);
        if (n) n.dismiss();
        root.syncHistoryModel();
        root.pruneExpire();
    }

    function dismissAll() {
        const list = server.trackedNotifications.values;
        for (let i = list.length - 1; i >= 0; --i) {
            const n = list[i];
            if (n) n.dismiss();
        }
        root.syncHistoryModel();
        root.pruneExpire();
    }

    function clearHistory() {
        dismissAll();
    }

    function setDND(enabled) {
        root.dndEnabled = enabled;
    }

    function toggleDND() {
        root.dndEnabled = !root.dndEnabled;
    }

    // ──────────────────────────────────────────────────────────────
    // Expiración
    //
    // El estado vive keyeado por id (property var _expire) porque el objeto
    // Notification se destruye al cerrarse: no se le pueden colgar
    // propiedades propias y leer las suyas después da ReferenceError.
    //
    // NO se usa Qt.callLater(fn, ms): el 2º argumento de callLater se PASA
    // a la función, no es un delay (se ejecutaría de inmediato). En su lugar
    // hay un único Timer de barrido que revisa las fechas límite.
    //
    // API pública usada por los toasts:
    //   pauseExpire(id) / resumeExpire(id)  → hover del toast
    //   expireInfo(id) / sentAt(id)         → barra de progreso y "hace X s"
    // ──────────────────────────────────────────────────────────────
    property var _expire: ({})

    // Un solo Timer vigila todas las notificaciones vivas.
    Timer {
        interval: 200
        repeat: true
        running: true
        onTriggered: root._sweepExpire()
    }

    // Devuelve la notificación viva por id, o null si ya se cerró.
    function byId(id) {
        const idx = root.findIndexById(id);
        return idx >= 0 ? server.trackedNotifications.values[idx] : null;
    }

    // Barrido: expira lo vencido. La poda del modelo la hace pruneExpire()
    // desde las señales del modelo (aquí la lista puede ir atrasada).
    function _sweepExpire() {
        const now = Date.now();
        let expired = false;
        for (const key in root._expire) {
            const info = root._expire[key];
            if (!info) { delete root._expire[key]; continue; }
            if (info.total > 0 && !info.paused && now - info.started >= info.total) {
                const n = root.byId(Number(key));
                if (n) {
                    n.expire();
                    expired = true;
                }
                // Si no está en el modelo (transient / DND) no hay nada que
                // cerrar aquí: su toast lleva su propia cuenta atrás.
                delete root._expire[key];
                continue;
            }
            // Red de seguridad ante entradas huérfanas.
            if (info.history && now - info.started > 3600000)
                delete root._expire[key];
        }
        if (expired) root.syncHistoryModel();
    }

    // Hover → pausa: congela el tiempo restante.
    function pauseExpire(id) {
        const info = root._expire[id];
        if (!info || info.paused || info.total <= 0) return;
        info.paused = true;
        info.remaining = Math.max(0, info.started + info.total - Date.now());
    }

    // Sale el hover → reanuda con el tiempo restante original.
    function resumeExpire(id) {
        const info = root._expire[id];
        if (!info || !info.paused || info.total <= 0) return;
        info.paused = false;
        const rem = info.remaining;
        info.remaining = 0;
        // Se reacomoda `started` para que el tiempo transcurrido total siga
        // siendo coherente (barra de progreso + hora relativa "hace X s").
        info.started = Date.now() - (info.total - rem);
        if (rem <= 0) {
            const n = root.byId(id);
            if (n) n.expire();
            delete root._expire[id];
            root.syncHistoryModel();
        }
    }

    // Timeout efectivo en ms de una notificación (misma política que aplica el
    // servicio al recibirla). Lo consultan los toasts para su cuenta atrás.
    function timeoutFor(notification) {
        return notification ? root.effectiveTimeoutMs(notification) : 0;
    }

    function sentAt(id) {
        const info = root._expire[id];
        return info ? info.started : 0;
    }

    // Invoca una acción por identificador. El toast guarda solo el
    // identifier en su snapshot, así que la búsqueda del objeto vivo
    // (NotificationAction) se hace aquí, sobre la notificación viva.
    function invokeAction(id, identifier) {
        const n = root.byId(id);
        if (!n || !n.actions) return false;
        for (let i = 0; i < n.actions.length; ++i) {
            const a = n.actions[i];
            if (a && a.identifier === identifier) {
                a.invoke();
                return true;
            }
        }
        return false;
    }

    // Helpers
    //
    // OJO: trackedNotifications es un UntypedObjectModel: se accede por
    // `.values[]` (NO tiene count ni get(i)). El comentario del header lo
    // dice: "You can work around this limitation using the values property
    // of the model to view it as a list".
    function findIndexById(id) {
        const list = server.trackedNotifications.values;
        for (let i = 0; i < list.length; ++i) {
            const n = list[i];
            if (n && n.id === id) return i;
        }
        return -1;
    }

    // Descarta la más antigua al superar historyLimit (la más reciente llega
    // después de esta llamada, así que el índice 0 es la más vieja).
    function enforceHistoryLimit() {
        let guard = root.historyLimit + 10;
        while (server.trackedNotifications.values.length > root.historyLimit && guard-- > 0) {
            const oldest = server.trackedNotifications.values[0];
            if (oldest) oldest.expire();
            else break;
        }
    }

    // ──────────────────────────────────────────────────────────────
    // Estado para la UI (campana + popup de hover)
    //
    // Ya no hay ventana de centro de notificaciones: todo se ve desde el
    // popup que aparece al hacer hover en la campana.
    // ──────────────────────────────────────────────────────────────

    // Contador y modelo para binding en UI (la campana, el popup)
    property int unreadCount: 0
    property var historyModel: []

    // Historial del más reciente al más antiguo.
    //
    // trackedNotifications.values llega en orden antiguo→reciente (índice 0 =
    // más viejo), que es lo que usa enforceHistoryLimit para descartar el más
    // viejo. Para la UI se invierte: lo más nuevo arriba.
    readonly property var historyNewestFirst: {
        const a = root.historyModel.slice();
        a.reverse();
        return a;
    }

    // Sincronizar con el modelo del server. Se expone `values` (lista real)
    // porque UntypedObjectModel no tiene count/get().
    function syncHistoryModel() {
        if (server && server.model) {
            root.historyModel = server.model.values;
            root.unreadCount = server.model.values.length;
        }
    }

    // Poda del estado de expiración. Se llama desde las señales del modelo
    // (objectInserted/RemovedPost), donde la lista ya está actualizada y es
    // la fuente de verdad.
    //
    // Solo se toca lo que entró al historial (`history: true`): las
    // entradas de transient / DND no están en el modelo y las necesita
    // vivas el toast para su cuenta atrás y su hora relativa.
    function pruneExpire() {
        const list = server.trackedNotifications.values;
        const alive = {};
        for (let i = 0; i < list.length; ++i) {
            const n = list[i];
            if (n) alive[n.id] = true;
        }
        for (const key in root._expire) {
            const info = root._expire[key];
            if (info && info.history && !alive[key]) delete root._expire[key];
        }
    }

    Component.onCompleted: {
        root.syncHistoryModel();
    }

    // Exponer server para acceso avanzado si hace falta
    readonly property var notificationServer: server
}