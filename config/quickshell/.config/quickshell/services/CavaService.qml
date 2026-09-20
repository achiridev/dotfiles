// services/CavaService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.globals

QtObject {
    id: root

    readonly property int barCount: 32
    property var bars: new Array(barCount).fill(0)

    // El visualizador solo se muestra con MÚSICA real (MPRIS / YouTube Music),
    // no con cualquier audio (Discord, videos, llamadas...). MprisService ya
    // filtra los players a solo YT Music.
    readonly property bool musicPlaying: MprisService.isPlaying

    // El toggle del panel de control monta/desmonta el visualizador. Cuando
    // está off, cava no debe correr (ni siquiera en reposo).
    readonly property bool visualizerEnabled: ControlState.visualizerEnabled

    // Estado público: ventana + render activos. Se apaga con histeresis de 3s
    // tras pausar la música para evitar parpadeos en pausas cortas.
    property bool active: false

    // Último frame recibido de cava. Se commitea a `bars` a ~30 fps máx: aunque
    // cava mande 60 fps y el monitor corra a 144 Hz, los bindings del render
    // solo se invalidan 30 veces por segundo.
    property var _pendingBars: null

    function _launch() {
        // Asignamos el comando para garantizar que $HOME esté resuelto.
        const configPath = Quickshell.env("HOME") + "/.config/cava/config";
        cavaProcess.command = ["cava", "-p", configPath];
        cavaProcess.running = true
    }

    function _start() {
        stopDelay.stop()
        root.active = true
        // cava se relanza aquí si no está vivo (relanzar al reanudar música
        // o al re-activar el visualizador desde el panel de control).
        if (!cavaProcess.running) root._launch()
    }

    function _stop() {
        root.active = false
        root._pendingBars = null
        root.bars = new Array(root.barCount).fill(0)
        // SIN música o con el visualizador desactivado, cerramos cava del
        // todo: no debe quedar el proceso vivo en segundo plano (visible en
        // btop). Matarlo destruye su nodo/enlaces de PipeWire, lo que con
        // quickshell 0.3.0 producía un crash (issue quickshell-mirror#529);
        // en 0.3.1 se relanza sin problema al volver a haber música.
        cavaProcess.running = false
    }

    property Process cavaProcess: Process {
        id: cavaProcess
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            // splitMarker por defecto = "\n", coincide con frame_delimiter=10
            onRead: data => {
                if (!data) return

                // Limpiamos y separamos por ";"
                const cleanData = data.trim();
                if (cleanData.length === 0) return;

                const values = cleanData.split(";")
                    .filter(v => v !== "")
                    .map(v => parseInt(v, 10) || 0);

                if (values.length === root.barCount)
                    root._pendingBars = values;
            }
        }
    }

    // Commit de frames a ~30 fps (interval 33 ms).
    // Nota: el root es QtObject (sin default property), así que los objetos
    // van como propiedades tipadas, igual que cavaProcess.
    property Timer commitTimer: Timer {
        interval: 33
        repeat: true
        running: root.active && cavaProcess.running

        onTriggered: {
            if (root._pendingBars !== null) {
                root.bars = Array.from(root._pendingBars);
                root._pendingBars = null;
            }
        }
    }

    // Histeresis al ocultar: si la música vuelve antes de 3s, no apagamos nada.
    property Timer stopDelay: Timer {
        interval: 3000
        onTriggered: root._stop()
    }

    onMusicPlayingChanged: {
        if (!root.visualizerEnabled) return
        if (root.musicPlaying) root._start()
        else stopDelay.restart()
    }

    // El toggle del panel de control es inmediato (sin histeresis): apagarlo
    // mata cava al instante; encenderlo con música en curso lo relanza.
    onVisualizerEnabledChanged: {
        if (root.visualizerEnabled) {
            if (root.musicPlaying) root._start()
        } else {
            stopDelay.stop()
            root._stop()
        }
    }

    Component.onCompleted: {
        // Solo lanzamos cava si ya hay música y el visualizador está activo;
        // si no, arrancará vía onMusicPlayingChanged cuando entre música.
        if (root.visualizerEnabled && root.musicPlaying) root._start()
    }
}
