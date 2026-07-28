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
