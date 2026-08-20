// services/CavaService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property int barCount: 60
    property var bars: new Array(barCount).fill(0)

    // El visualizador solo se muestra con MÚSICA real (MPRIS / YouTube Music),
    // no con cualquier audio (Discord, videos, llamadas...). MprisService ya
    // filtra los players a solo YT Music.
    readonly property bool musicPlaying: MprisService.isPlaying

    // Estado público: ventana + render activos. Se apaga con histeresis de 3s
    // tras pausar la música para evitar parpadeos en pausas cortas.
    property bool active: false

    // Último frame recibido de cava. Se commitea a `bars` a ~30 fps máx: aunque
    // cava mande 60 fps y el monitor corra a 144 Hz, los bindings del render
    // solo se invalidan 30 veces por segundo.
    property var _pendingBars: null

    function _start() {
        stopDelay.stop()
        root.active = true
    }

    function _stop() {
        root.active = false
        root._pendingBars = null
        root.bars = new Array(root.barCount).fill(0)
    }

    // cava vive durante TODA la sesión (nunca se mata a mitad de sesión):
    // destruir su nodo/enlaces de PipeWire dispara un crash de quickshell
    // 0.3.0 (issue quickshell-mirror#529: SEGV en pw_proxy_destroy desde
    // PwBindableObject::unbind). El costo en reposo es ~0% porque cava duerme
    // el FFT con sleep_timer=2 (~/.config/cava/config); el costo real (render)
    // lo gobierna `active`, que sí se apaga sin música.
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
        if (root.musicPlaying) root._start()
        else stopDelay.restart()
    }

    Component.onCompleted: {
        // Asignamos el comando para garantizar que $HOME esté resuelto
        const configPath = Quickshell.env("HOME") + "/.config/cava/config";
        cavaProcess.command = ["cava", "-p", configPath];
        cavaProcess.running = true
        // Si quickshell arranca con música ya sonando, mostramos directo.
        if (root.musicPlaying) root.active = true
    }
}
