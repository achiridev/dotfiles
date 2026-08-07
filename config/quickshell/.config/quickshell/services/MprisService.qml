// services/MprisService.qml
// Servicio MPRIS orientado a YouTube Music.
//
// Filtra los players del bus para quedarse SOLO con YouTube Music:
//   - Firefox/Zen exponen "xesam:url" (la URL de la pestaña) en metadata, así que
//     detectamos con exactitud music.youtube.com y nunca videos de youtube.com.
//   - Chromium/Brave NO exponen la URL de la pestaña (bug conocido); se aceptan
//     únicamente si su identidad está en la allowlist y usas una instancia
//     dedicada de música (proceso aparte = bus MPRIS propio).
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

import qs.globals

Singleton {
    id: root

    // ================================================================
    // Players y filtrado
    // ================================================================

    readonly property bool hasActivePlasmaIntegration: Mpris.players.values.some(
        p => p.dbusName?.startsWith("org.mpris.MediaPlayer2.plasma-browser-integration")
    )

    // Excluye buses "fantasma" que solo duplican metadata:
    // playerctld (proxea el player actual) y los duplicados nativos cuando
    // plasma-browser-integration ya expone el mismo contenido.
    function isRealPlayer(p) {
        if (!p) return false;
        return (
            !(root.hasActivePlasmaIntegration && p.dbusName?.startsWith("org.mpris.MediaPlayer2.firefox"))
            && !(root.hasActivePlasmaIntegration && p.dbusName?.startsWith("org.mpris.MediaPlayer2.chromium"))
            && !p.dbusName?.startsWith("org.mpris.MediaPlayer2.playerctld")
            && !(p.dbusName?.endsWith(".mpd") && !p.dbusName.endsWith("MediaPlayer2.mpd"))
        );
    }

    // El corazón del requisito "solo YouTube Music".
    function isYouTubeMusic(p) {
        if (!p) return false;
        const url = p.metadata?.["xesam:url"] ?? "";
        if (typeof url === "string" && url.length > 0) {
            // Firefox / Zen: la URL de la pestaña viaja en la metadata.
            return url.startsWith("https://music.youtube.com/") || url.startsWith("http://music.youtube.com/");
        }
        // Chromium / Brave: sin URL de pestaña. Solo aceptable si la identidad
        // está en la allowlist (instancia dedicada de música).
        return AppState.musicAllowChromiumBrowsers
            && AppState.musicTrustedBrowserIdentities.includes(p.identity);
    }

    function isMusicPlayer(p) {
        return root.isRealPlayer(p) && root.isYouTubeMusic(p);
    }

    function musicPlayers() {
        return Mpris.players.values.filter(p => root.isMusicPlayer(p));
    }

    // ================================================================
    // Player activo (patrón end-4/dots-hyprland adaptado)
    // ================================================================

    property MprisPlayer trackedPlayer: null
    readonly property MprisPlayer activePlayer: root.trackedPlayer ?? root.musicPlayers()[0] ?? null
    property bool __reverse: false

    signal trackChanged(bool reverse)

    function nextCandidate() {
        const players = root.musicPlayers();
        for (const p of players) {
            if (p.isPlaying) return p;
        }
        return players[0] ?? null;
    }

    function setActive(p) {
        if (!root.isMusicPlayer(p)) return;
        const players = root.musicPlayers();
        const prevIdx = players.indexOf(root.trackedPlayer);
        const newIdx = players.indexOf(p);
        root.__reverse = prevIdx >= 0 && newIdx >= 0 && newIdx < prevIdx;
        root.trackedPlayer = p;
    }

    // Sigue a cada player real; solo asigna a YT Music.
    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onCompleted: {
                if (root.trackedPlayer === null && root.isMusicPlayer(modelData) && modelData.isPlaying) {
                    root.setActive(modelData);
                }
            }

            Component.onDestruction: {
                if (root.trackedPlayer === modelData) {
                    root.trackedPlayer = root.nextCandidate();
                }
            }

            function onPlaybackStateChanged() {
                if (!root.isMusicPlayer(modelData)) return;
                if (modelData.isPlaying) {
                    root.setActive(modelData);
                }
            }
        }
    }

    Connections {
        target: root.activePlayer

        function onPostTrackChanged() { root.updateTrack(); }
        function onTrackArtUrlChanged() {
            // La carátula puede llegar DESPUÉS del resto de la metadata
            // (cantata y otros mandan cover updates antes que el track).
            const r = root.__reverse;
            root.updateTrack();
            root.__reverse = r;
        }
    }

    onActivePlayerChanged: root.updateTrack()
    onTrackedPlayerChanged: root.updateTrack()
    Component.onCompleted: root.updateTrack()

    // ================================================================
    // Track activo
    // ================================================================

    function videoId(p) {
        if (!p) return "";
        const url = p.metadata?.["xesam:url"] ?? "";
        if (typeof url !== "string") return "";
        const m = url.match(/[?&]v=([A-Za-z0-9_-]{11})/);
        return m ? m[1] : "";
    }

    property var activeTrack: ({
        uniqueId: 0,
        title: "",
        artist: "",
        album: "",
        artUrl: "",
        fallbackArtUrl: "",
        videoId: "",
    })

    function updateTrack() {
        const p = root.activePlayer;
        const vid = root.videoId(p);
        root.activeTrack = {
            uniqueId: p?.uniqueId ?? 0,
            title: p?.trackTitle ?? "",
            artist: p?.trackArtist ?? "",
            album: p?.trackAlbum ?? "",
            artUrl: p?.trackArtUrl ?? "",
            fallbackArtUrl: vid ? "https://i.ytimg.com/vi/" + vid + "/hqdefault.jpg" : "",
            videoId: vid,
        };
        root.trackChanged(root.__reverse);
        root.__reverse = false;
    }

    // Arte efectivo: el que manda el player o el fallback por videoId.
    readonly property string effectiveArtUrl: {
        const t = root.activeTrack;
        if (t.artUrl && t.artUrl.length > 0) return t.artUrl;
        return t.fallbackArtUrl;
    }

    // ================================================================
    // Posición / duración (en segundos)
    // ================================================================

    readonly property double position: root.activePlayer?.position ?? 0
    // length solo se confía cuando la metadata trae mpris:length: si falta
    // (streams en vivo, o metadata incompleta), quickshell devuelve la posición
    // actual como length, lo que rompía el total y la barra.
    readonly property bool lengthSupported: root.activePlayer?.lengthSupported ?? false
    readonly property double length: (root.activePlayer && root.lengthSupported) ? root.activePlayer.length : 0
    readonly property bool canSeek: root.activePlayer?.canSeek ?? false
    readonly property bool positionSupported: root.activePlayer?.positionSupported ?? false

    readonly property double positionRatio: root.length > 0
        ? Math.max(0, Math.min(1, root.position / root.length))
        : 0

    readonly property string positionLabel: root.formatTime(root.position)
    readonly property string lengthLabel: root.lengthSupported ? root.formatTime(root.length) : "--:--"

    function formatTime(secs) {
        if (!isFinite(secs) || secs < 0) return "0:00";
        const m = Math.floor(secs / 60);
        const s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // position no es reactiva por defecto (documentado en quickshell); se
    // emite positionChanged 1 vez por segundo mientras hay player activo.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const p = root.activePlayer;
            if (p && p.positionSupported) p.positionChanged();
        }
    }

    // ================================================================
    // Estado de control
    // ================================================================

    readonly property bool isPlaying: root.activePlayer?.isPlaying ?? false
    readonly property bool canControl: root.activePlayer?.canControl ?? false
    readonly property bool canTogglePlaying: root.activePlayer?.canTogglePlaying ?? false
    readonly property bool canGoNext: root.activePlayer?.canGoNext ?? false
    readonly property bool canGoPrevious: root.activePlayer?.canGoPrevious ?? false
    readonly property bool volumeSupported: root.activePlayer?.volumeSupported ?? false
    readonly property bool shuffleSupported: root.activePlayer?.shuffleSupported ?? false
    readonly property bool loopSupported: root.activePlayer?.loopSupported ?? false
    readonly property double volume: root.activePlayer?.volume ?? 0
    readonly property bool shuffle: root.activePlayer?.shuffle ?? false
    readonly property var loopState: root.activePlayer?.loopState ?? MprisLoopState.None

    // ================================================================
    // Acciones
    // ================================================================

    function togglePlaying() {
        const p = root.activePlayer;
        if (p && p.canTogglePlaying) p.togglePlaying();
    }

    function next() {
        const p = root.activePlayer;
        if (p && p.canGoNext) p.next();
    }

    function previous() {
        const p = root.activePlayer;
        if (p && p.canGoPrevious) p.previous();
    }

    function seekTo(secs) {
        const p = root.activePlayer;
        if (p && p.canSeek && p.positionSupported) p.setPosition(secs);
    }

    function setVolume(v) {
        const p = root.activePlayer;
        if (p && p.volumeSupported && p.canControl) {
            p.setVolume(Math.max(0, Math.min(1, v)));
        }
    }

    function toggleShuffle() {
        const p = root.activePlayer;
        if (p && p.shuffleSupported && p.canControl) p.shuffle = !p.shuffle;
    }

    function cycleLoop() {
        const p = root.activePlayer;
        if (!p || !p.loopSupported || !p.canControl) return;
        p.loopState = p.loopState === MprisLoopState.None
            ? MprisLoopState.Playlist
            : p.loopState === MprisLoopState.Playlist
                ? MprisLoopState.Track
                : MprisLoopState.None;
    }

    // ================================================================
    // Abrir / enfocar YouTube Music
    // ================================================================

    property Process openProcess: Process { running: false }
    property Process miscProcess: Process { running: false }

    function __expand(str) {
        const home = Quickshell.env("HOME") ?? "";
        return str.replace(/\$HOME/g, home).replace(/^~(?=\/)/, home);
    }

    function openYouTubeMusic() {
        const parts = AppState.musicOpenCommand.split(/\s+/).filter(s => s.length > 0).map(root.__expand);
        parts.push("https://music.youtube.com/");
        root.openProcess.running = false;
        root.openProcess.command = parts;
        root.openProcess.running = true;
    }

    function focusPlayer() {
        if (AppState.musicFocusSelector === "") return;
        root.miscProcess.running = false;
        // Hyprland 0.55+ usa dispatch Lua; la sintaxis legacy
        // (focuswindow class:...) falla en silencio.
        root.miscProcess.command = [
            "hyprctl", "dispatch",
            'hl.dsp.focus({window="' + AppState.musicFocusSelector + '"})'
        ];
        root.miscProcess.running = true;
    }
}
