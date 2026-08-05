// service/AudioService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton
{
    id: root

    readonly property real volumeStep: 0.01   // 1% por scroll / tecla
    readonly property real minVolume: 0.0
    readonly property real maxVolume: 1.5     // permite boost hasta 150%


    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool ready: Pipewire.ready
    readonly property bool sinkReady: sink !== null && sink.ready
    readonly property bool sourceReady: source !== null && source.ready

    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : true

    readonly property real micVolume: (source && source.audio) ? source.audio.volume : 0
    readonly property bool micMuted: (source && source.audio) ? source.audio.muted : true

    readonly property int volumePercent: Math.round(volume * 100)
    readonly property int micVolumePercent: Math.round(micVolume * 100)

    readonly property string sinkName: displayName(sink)
    readonly property string sourceName: displayName(source)

    // Listas: dispositivos y streams de aplicaciones
    property list<PwNode> sinks: []            // salidas físicas/virtuales
    property list<PwNode> sources: []          // entradas físicas/virtuales
    property list<PwNode> playbackStreams: []  // apps reproduciendo audio
    property list<PwNode> recordingStreams: [] // apps grabando (mic, screen share, etc)

    // Nodos cuyos propertiesChanged ya tienen conexión para evitar duplicados.
    property var hookedNodes: new Set()

    function refreshNodes() {
        const nodes = Pipewire.nodes.values;

        // Los props de un nodo pueden llegar después de su aparición en el grafo
        // (onInfo llega tras el evento global del registry). Re-clasificamos cuando
        // cambian para no dejar streams en el grupo equivocado.
        for (const node of nodes) {
            if (!hookedNodes.has(node)) {
                hookedNodes.add(node);
                node.propertiesChanged.connect(() => root.refreshNodes());
            }
        }

        const _sinks = [];
        const _sources = [];
        const _playback = [];
        const _recording = [];

        for (const node of nodes) {
            if (!node.audio) continue; // solo nodos de audio

            if (node.isStream) {
                // Stream de una app:
                //  isSink=true  -> Stream/Output/Audio  => reproducción (emite audio)
                //  isSink=false -> Stream/Input/Audio   => grabación (captura audio)
                if (node.isSink) {
                    _playback.push(node);
                } else {
                    // Excepción: cava es un capturador/visualizador del monitor,
                    // pero se lista en "Reproduciendo" para poder controlarlo ahí.
                    const nodeName = node.properties["node.name"] || "";
                    if (nodeName.includes("cava")) _playback.push(node);
                    else _recording.push(node);
                }
            } else {
                // Dispositivo real (hardware o virtual, ej. monitor de sink)
                if (node.isSink) _sinks.push(node);
                else _sources.push(node);
            }
        }

        sinks = _sinks;
        sources = _sources;
        playbackStreams = _playback;
        recordingStreams = _recording;
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.refreshNodes(); }
    }

    Component.onCompleted: refreshNodes()

    // Todo nodo cuyas propiedades de audio queremos leer/escribir tiene
    // que estar "trackeado". Sin esto, node.audio.volume/muted no son válidos.
    PwObjectTracker {
        objects: [
            ...root.sinks,
            ...root.sources,
            ...root.playbackStreams,
            ...root.recordingStreams,
        ]
    }

    // Nombres legibles
    function displayName(node) {
        if (!node) return "";
        if (node.isStream) {
            const appName = node.properties["application.name"];
            if (appName) return appName;
        }
        return node.description || node.nickname || node.name || "Desconocido";
    }
    function subtitle(node) {
        if (!node) return ""
        // Si es un reproductor multimedia, mostrar título de la pista si está disponible
        const mediaName = node.properties["media.name"]
        if (mediaName) return mediaName
        // Si no, mostrar el nombre técnico del binario/proceso
        return node.properties["application.process.binary"] || node.name || ""
    }

    // Subtítulo de un dispositivo: perfil/card activo o nombre técnico.
    function deviceSubtitle(node) {
        if (!node) return ""
        const profile = node.properties["device.profile.description"]
        if (profile) return profile
        const product = node.properties["device.product.name"]
        if (product) return product
        return node.name || ""
    }

    function iconName(node) {
        // Útil si querés mostrar el ícono real de la app con
        // Quickshell.Widgets.IconImage (opcional).
        if (!node) return "";
        return node.properties["application.icon-name"] || "";
    }

    // Glifo Nerd Font para un dispositivo (sink/source) según su tipo.
    // Reactivo: al leer node.properties dentro de un binding se re-evalúa
    // cuando llegan los props del nodo (NOTIFY propertiesChanged).
    function nodeGlyph(node) {
        if (!node) return "";
        if (node.isStream) return "󰎆"; // nota musical genérica
        const haystack = ((node.description || "") + " " + (node.name || "")).toLowerCase();
        if (haystack.includes("hdmi") || haystack.includes("displayport")) return "󰽥"; // monitor/tv
        if (haystack.includes("headphone") || haystack.includes("headset")) return "󰋋"; // auriculares
        if (haystack.includes("bluetooth") || haystack.includes("bluez")) return "󰂯"; // bluetooth
        if (haystack.includes("speaker")) return "󰓃"; // parlante
        if (!node.isSink) return "󰍬"; // micrófono
        return "󰕾"; // salida genérica
    }

    // Glifo de volumen del sink por defecto, según nivel.
    function volumeGlyph() {
        if (root.muted) return "󰝟"; // mute
        if (volumePercent < 30) return "󰕿"; // bajo
        if (volumePercent < 70) return "󰖀"; // medio
        return "󰕾"; // alto
    }

    // Control genérico de volumen / mute (sirve para cualquier PwNode:
    // sink, source o stream de una app puntual)
    function setVolume(node, vol) {
        if (!node || !node.ready || !node.audio) return;
        node.audio.volume = Math.max(minVolume, Math.min(maxVolume, vol));
    }

    function setMuted(node, value) {
        if (!node || !node.ready || !node.audio) return;
        node.audio.muted = value;
    }

    function toggleMuted(node) {
        if (!node || !node.ready || !node.audio) return;
        node.audio.muted = !node.audio.muted;
    }

    function stepVolume(node, delta) {
        if (!node || !node.ready || !node.audio) return;
        setVolume(node, node.audio.volume + delta);
    }

    // Atajos para el sink/source por defecto (los que usa el widget de barra)
    function increaseVolume(step) { stepVolume(sink, step !== undefined ? step : volumeStep); }
    function decreaseVolume(step) { stepVolume(sink, -(step !== undefined ? step : volumeStep)); }
    function toggleMute() { toggleMuted(sink); }

    function increaseMicVolume(step) { stepVolume(source, step !== undefined ? step : volumeStep); }
    function decreaseMicVolume(step) { stepVolume(source, -(step !== undefined ? step : volumeStep)); }
    function toggleMicMute() { toggleMuted(source); }

    // Cambiar el dispositivo de salida/entrada por defecto
    function setDefaultSink(node) {
        if (!node) return;
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        if (!node) return;
        Pipewire.preferredDefaultAudioSource = node;
    }
}
