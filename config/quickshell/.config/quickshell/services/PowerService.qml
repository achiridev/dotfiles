// services/PowerService.qml
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Item {
    id: root

    Process {
        id: powerProcess
    }

    function openPowerMenu() {
        // Garantizamos la resolución correcta de $HOME usando Quickshell.env
        const scriptPath = Quickshell.env("HOME") + "/.config/waybar/scripts/power.sh"
        powerProcess.command = ["bash", scriptPath]
        powerProcess.running = true
    }
}
