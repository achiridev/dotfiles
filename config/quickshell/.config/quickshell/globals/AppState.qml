// core/AppState.qml
pragma Singleton
import Quickshell
import QtQuick
import QtQuick.Layouts

// import Quickshell.Services.Network // (NetworkManager)

QtObject {
    id: root
    Component.onCompleted: {
        console.log("===== APP STATE =====")
    }

    // ==========================================
    // MUSIC (YouTube Music via MPRIS)
    // ==========================================
    // Comando que lanza YouTube Music en tu navegador.
    //   - Zen / Firefox:  "zen-browser" (o "firefox")
    //   - Brave dedicado: "brave --user-data-dir=$HOME/.config/brave-music"
    // (la URL de music.youtube.com se concatena al abrir desde el widget)
    property string musicOpenCommand: "zen-browser"

    // Selector de ventana para enfocar el navegador de música con hyprctl.
    // Hyprland 0.55+ usa dispatch Lua: hl.dsp.focus({window="<selector>"}).
    // El selector es regex full-match (requiere .* alrededor); "title:" apunta
    // a la pestaña de música incluso con varias ventanas del mismo navegador.
    property string musicFocusSelector: "title:.*YouTube Music.*"

    // Familia Chromium (Brave) no expone la URL de la pestaña en MPRIS,
    // así que no podemos filtrar por dominio. Con una instancia dedicada
    // de música (proceso aparte) el filtro se delega a la identidad.
    property bool musicAllowChromiumBrowsers: true
    property list<string> musicTrustedBrowserIdentities: ["Brave", "Chromium"]

    // Duracións de animación del ecosistema musical (ms)
    property int musicAnimFast: 120
    property int musicAnimBase: 180
    property int musicAnimSlow: 260

    // ==========================================
    // BRILLO (pantalla + teclado Acer RGB)
    // ==========================================
    // Dispositivo de retroiluminación principal (ver `brightnessctl -l`).
    property string brightnessDevice: "intel_backlight"

    // Script del módulo Acer Predator (brillo + RGB del teclado).
    // Repo: JafarAkhondali/acer-predator-turbo-and-rgb-keyboard-linux-module
    property string keyboardRgbScriptPath: "~/Descargas/acer-predator-turbo-and-rgb-keyboard-linux-module/facer_rgb.py"

//    // ==========================================
//    // 2. SISTEMA DE RED (CONNECTIVITY)
//    // ==========================================
//    property var networkInfo: NetworkService {
//        // Monitorea el estado de NetworkManager
//    }
//
//    // Retorna true si hay conexión activa a internet
//    readonly property bool isConnected: networkInfo.connectivity === NetworkConnectivity.Full
//
//    readonly property string networkName: {
//        if (!isConnected) return "Desconectado";
//        if (networkInfo.primaryConnection) {
//            return networkInfo.primaryConnection.id; // Retorna el SSID del Wi-Fi o "Wired"
//        }
//        return "Conectado";
//    }
//
//    readonly property string networkIcon: {
//        if (!isConnected) return "󰖪";
//        if (networkInfo.primaryConnection && networkInfo.primaryConnection.type.includes("wifi")) {
//            return "󰤨";
//        }
//        return "󰈀"; // Icono de Ethernet
//    }
}
