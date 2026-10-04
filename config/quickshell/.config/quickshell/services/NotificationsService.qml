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
import qs.services

Singleton {
    id: root

    // ──────────────────────────────────────────────────────────────
    // Retención: TODO se guarda, sin excepciones.
    //
    // Antes había un filtro de "paridad con swaync" que se tragaba algunas
    // notificaciones (batería, aviso de inactividad). Se eliminó: el usuario
    // pidió que ninguna se pierda. isSwallowed() queda como punto de extensión
    // documentado, pero no traga nada.
    //
    // Las dos DURACIONES están desacopladas a propósito:
    //   * timeoutFor()      → cuánto vive el TOAST en pantalla
    //   * historyTimeoutMs()→ cuánto vive en el HISTORIAL del popup
    // Antes eran la misma, así que "8s" quitaba la notificación del centro.
    // ──────────────────────────────────────────────────────────────
    function isSwallowed(notification) {
        // Extensión para el futuro. Ahora mismo: no traga nada.
        return false;
    }

    // Timeout del TOAST (lo que se ve en pantalla), en ms.
    // 0 = no se cierra solo.
    function timeoutFor(notification) {
        // Un TEMA manda: p. ej. batería baja usa 0 = persistente.
        const theme = root.themeForNotification(notification);
        if (theme) return theme.timeoutMs;

        if (notification.urgency === NotificationUrgency.Critical) return 0;
        if (notification.expireTimeout > 0) return notification.expireTimeout * 1000;
        if (notification.urgency === NotificationUrgency.Low)
            return AppTheme.notificationsTimeoutLow * 1000;
        return AppTheme.notificationsTimeoutNormal * 1000;
    }

    // Timeout del HISTORIAL (lo que queda guardado en el popup), en ms.
    // 0 = permanente: solo lo quita el usuario.
    function historyTimeoutMs(notification) {
        // ⚠️ Las notificaciones CON ACCIONES sí expiran, y es a propósito.
        // `notify-send -A ...` implica --wait: el script queda BLOQUEADO
        // esperando un clic (ver bin/.local/bin/screenshot.sh). Si la
        // notificación no se cerrara nunca, el script se quedaría colgado
        // para siempre. Es la única excepción a "todo se guarda".
        if (notification.actions && notification.actions.length > 0)
            return root.timeoutFor(notification);

        // Resto: permanente.
        return 0;
    }

    // Tema aplicable a una notificación (por appName), o null.
    function themeForNotification(notification) {
        return notification ? NotificationThemes.resolve(notification.appName) : null;
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
            // 1) Punto de extension: isSwallowed() ya no traga nada, pero si
            //    algun dia se usa, sale aqui y no se guarda nada.
            if (root.isSwallowed(notification)) {
                notification.tracked = false;
                return;
            }

            // 2) Do Not Disturb: NO se muestra toast, pero SI se guarda.
            //    La critical siempre se muestra.
            const blockedByDnd = root.dndEnabled
                && notification.urgency !== NotificationUrgency.Critical;

            // 3) TODO se trackea, incluidos los transient y los de DND.
            //    tracked = true es lo que mantiene el objeto vivo y lo mete
            //    en el historial del popup. Untracked = Quickshell destruye
            //    el Notification al salir del handler, o sea que se pierde.
            notification.tracked = true;

            // Estado de expiracion del HISTORIAL, keyeado por id.
            // (El objeto Notification se destruye al cerrarse, asi que el
            // estado vive aqui y no en el propio notification.)
            root._expire[notification.id] = {
                total: root.historyTimeoutMs(notification),
                started: Date.now(),
                paused: false,
                remaining: 0,
                history: true
            };

            // Red de seguridad por memoria: se descarta la mas antigua al
            // superar historyLimit (500). No se nota en el uso normal.
            root.enforceHistoryLimit();

            // Senal para UI (toast, badge). DND silencia el toast, no el
            // historial.
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

    // Red de seguridad por memoria, NO una política de limpieza: todo se
    // guarda hasta que el usuario lo quita. Al superar este número se
    // descarta la más antigua. 500 es de sobra para el uso normal.
    property int historyLimit: 500

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
    // Expiración del HISTORIAL. Solo actúa sobre lo que tiene total > 0, o sea
    // las notificaciones CON ACCIONES (ver historyTimeoutMs). El resto tiene
    // total = 0 (permanentes) y aquí no se tocan: viven hasta que el usuario
    // las quite.
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
        root._applySettings();
    }

    // ──────────────────────────────────────────────────────────────
    // Ajustes persistidos por el Panel de Control
    //
    // SettingsService lee settings.json de forma asíncrona, así que el estado
    // guardado puede llegar después de este Component.onCompleted.
    // ──────────────────────────────────────────────────────────────
    Connections {
        target: SettingsService
        function onReadyChanged() {
            if (SettingsService.ready) root._applySettings()
        }
    }

    function _applySettings() {
        if (!SettingsService.ready) return;
        root.dndEnabled = SettingsService.dndEnabled;
        root.historyLimit = SettingsService.historyLimit;
    }

    // Exponer server para acceso avanzado si hace falta
    readonly property var notificationServer: server
}