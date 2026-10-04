// services/SettingsService.qml
// Persistencia de las configurações del Panel de Control.
//
// Es la única fuente de verdad de lo que el usuario configura desde el Centro
// de Control: qué componentes de Quickshell están activos y los ajustes de
// notificaciones. Al arrancar lee settings.json; cada cambio se guarda con un
// debounce para no escribir en disco en cada frame.
//
// Ubicación: $XDG_STATE_HOME/quickshell/settings.json (~/.local/state/...)
//
// NO se persisten los colores: Wallust los genera y los reparte por sus
// plantillas (colors.lua, colors.conf, colors.rasi, colors.css), y se
// regeneran cada vez que cambia el fondo.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============================================================
    // RUTAS
    // ============================================================
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (homeDir + "/.local/state")) + "/quickshell"
    readonly property string filePath: stateDir + "/settings.json"

    // ============================================================
    // ESTADO PERSISTIDO
    //
    // Los defaults son "todo activado", igual que los de ControlState.
    // ============================================================
    property bool barEnabled: true
    property bool overviewEnabled: true
    property bool wallpapersEnabled: true
    property bool launcherEnabled: true
    property bool activateEnabled: true
    property bool visualizerEnabled: true
    property bool notificationsEnabled: true
    property bool dndEnabled: false
    property int historyLimit: 500

    // Claves a persistir. Se usa para leer y escribir sin repetir la lista
    // nueve veces; las propiedades de arriba son la declaración real de cada
    // ajuste.
    readonly property var settingKeys: [
        "barEnabled",
        "overviewEnabled",
        "wallpapersEnabled",
        "launcherEnabled",
        "activateEnabled",
        "visualizerEnabled",
        "notificationsEnabled",
        "dndEnabled",
        "historyLimit"
    ]

    // ============================================================
    // CICLO DE VIDA DE LA CARGA
    //
    // ready = false  → el archivo aún no se ha leído. Nadie debe guardar nada,
    //                   o los defaults pisarían la config guardada del usuario.
    // ready = true   → ya se leyó (o se confirmó que no existía). A partir de
    //                   aquí cada cambio se persiste.
    // ============================================================
    property bool ready: false

    // Se pone true mientras se aplica el JSON para que los on<Prop>Changed no
    // disparen un guardado en cascada durante la propia carga.
    property bool _applying: false

    Component.onCompleted: root._startLoad()

    // mkdir -p del directorio de estado. FileView no crea directorios y su
    // escritura atómica (temp + rename) fallaría sin él.
    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.stateDir]
        running: false
        onExited: root._openSettingsFile()
    }

    // Si el mkdir se demora o falla, se lee igualmente: la carga fallará
    // (loadFailed) y se usarán los defaults, que es el comportamiento correcto.
    Timer {
        id: mkdirFallback
        interval: 1000
        repeat: false
        onTriggered: root._openSettingsFile()
    }

    FileView {
        id: settingsFile
        path: ""
        preload: true
        watchChanges: false
        printErrors: false

        onLoaded: {
            root._applyJson(settingsFile.text())
            root.ready = true
        }

        // No existe todavía (primera ejecución) o no se pudo leer: defaults.
        // En el caso "no existe" se escribe el archivo para que a partir de
        // ahora sí haya persistencia.
        onLoadFailed: (error) => {
            root.ready = true
            root.saveNow()
        }
    }

    // ============================================================
    // LECTURA
    // ============================================================
    function _startLoad() {
        mkdirProc.running = true
        mkdirFallback.start()
    }

    function _openSettingsFile() {
        if (settingsFile.path !== "") return
        mkdirFallback.stop()
        settingsFile.path = "file://" + root.filePath
    }

    function _applyJson(raw) {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            // JSON corrupto o archivo vacío: se conservan los defaults.
            return;
        }
        if (!data || typeof data !== "object") return;

        root._applying = true;
        const keys = root.settingKeys;
        for (let i = 0; i < keys.length; ++i) {
            const key = keys[i];
            if (data[key] !== undefined) root[key] = data[key];
        }
        root._applying = false;
    }

    // ============================================================
    // ESCRITURA
    // ============================================================

    // Entrada pública: la usan ControlState y NotificationsSection al cambiar
    // algo. No hace nada hasta que la carga haya terminado.
    function scheduleSave() {
        if (!root.ready || root._applying) return;
        saveTimer.restart();
    }

    function saveNow() {
        if (!root.ready) return;

        const out = {};
        const keys = root.settingKeys;
        for (let i = 0; i < keys.length; ++i) {
            const key = keys[i];
            out[key] = root[key];
        }
        settingsFile.setText(JSON.stringify(out, null, 2) + "\n");
    }

    Timer {
        id: saveTimer
        interval: 400
        repeat: false
        onTriggered: root.saveNow()
    }

    // ============================================================
    // CUALQUIER CAMBIO MARCA EL ESTADO COMO SUCIO
    // ============================================================
    function _onChanged() {
        root.scheduleSave();
    }

    onBarEnabledChanged: _onChanged()
    onOverviewEnabledChanged: _onChanged()
    onWallpapersEnabledChanged: _onChanged()
    onLauncherEnabledChanged: _onChanged()
    onActivateEnabledChanged: _onChanged()
    onVisualizerEnabledChanged: _onChanged()
    onNotificationsEnabledChanged: _onChanged()
    onDndEnabledChanged: _onChanged()
    onHistoryLimitChanged: _onChanged()
}