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
            // 1) Tragadas por regla de paridad con swaync
            if (root.isSwallowed(notification)) {
                notification.tracked = false;
                return;
            }

            // 2) Transientes (marcadas por el app como temporales)
            if (notification.transient) {
                notification.tracked = false;
                return;
            }

            // 3) Do Not Disturb: solo deja pasar critical
            if (root.dndEnabled && notification.urgency !== NotificationUrgency.Critical) {
                notification.tracked = false;
                return;
            }

            // Trackear: esto la guarda en trackedNotifications y evita que se destruya
            notification.tracked = true;

            // Estado del timer de auto-expiración, keyeado por id.
            // (El objeto Notification se destruye al cerrarse, así que el
            // estado vive aquí, no en el propio notification.)
            // El barrido (Timer del servicio) se encarga de expirar.
            const ms = root.effectiveTimeoutMs(notification);
            root._expire[notification.id] = {
                total: ms,
                started: Date.now(),
                paused: false,
                remaining: 0,
                seen: false
            };

            // Límite de historial: se expira la más antigua (no la que llega)
            root.enforceHistoryLimit();

            // Sincronizar modelo de historial / contador
            root.syncHistoryModel();

            // Señal para UI (toast, badge, etc.)
            root.notificationReceived(notification);
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

    // Barrido: expira lo vencido y poda lo que ya no está en el modelo.
    function _sweepExpire() {
        const now = Date.now();
        let expired = false;
        for (const key in root._expire) {
            const info = root._expire[key];
            if (!info) { delete root._expire[key]; continue; }
            if (info.total > 0 && !info.paused) {
                const id = Number(key);
                if (now - info.started >= info.total) {
                    const n = root.byId(id);
                    if (n) n.expire();
                    delete root._expire[key];
                    expired = true;
                    continue;
                }
            }
            // Poda: la notificación ya no está en el modelo (dismiss, action,
            // cierre remoto...) → su estado ya no sirve.
            //
            // OJO: `tracked = true` actualiza trackedNotifications de forma
            // diferida, así que una entrada recién creada puede no aparecer
            // todavía en el modelo. Por eso solo se poda si ya la vimos ahí
            // (seen), o si es mucho más vieja que su timeout (evita fugas en
            // el caso de que se cierre antes de llegar al modelo).
            const pos = root.findIndexById(Number(key));
            if (pos >= 0) {
                info.seen = true;
            } else if (info.seen || now - info.started > info.total + 600000) {
                delete root._expire[key];
            }
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

    function expireInfo(id) {
        return root._expire[id];
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
    // Centro de notificaciones (estado de ventana)
    // ──────────────────────────────────────────────────────────────
    property bool notificationCenterOpen: false

    // Contador y modelo para binding en UI (la campana, el popup, el centro)
    property int unreadCount: 0
    property var historyModel: []

    // Sincronizar con el modelo del server. Se expone `values` (lista real)
    // porque UntypedObjectModel no tiene count/get().
    function syncHistoryModel() {
        if (server && server.model) {
            root.historyModel = server.model.values;
            root.unreadCount = server.model.values.length;
        }
    }

    // Poda explícita del estado de expiración tras un borrado masivo.
    // Respeta el mismo "seen" que el barrido: trackedNotifications se
    // actualiza de forma diferida respecto a `tracked = true`.
    function pruneExpire() {
        const list = server.trackedNotifications.values;
        const alive = {};
        for (let i = 0; i < list.length; ++i) {
            const n = list[i];
            if (n) { alive[n.id] = true; if (root._expire[n.id]) root._expire[n.id].seen = true; }
        }
        for (const key in root._expire) {
            if (!alive[key] && root._expire[key].seen) delete root._expire[key];
        }
    }

    Component.onCompleted: {
        root.syncHistoryModel();
    }

    // Exponer server para acceso avanzado si hace falta
    readonly property var notificationServer: server
}