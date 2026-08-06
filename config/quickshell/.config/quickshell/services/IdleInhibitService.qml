// services/IdleInhibitService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Inhibidor de inactividad. Mantiene un proceso persistente
// (systemd-inhibit --what=idle) que sostiene un inhibidor de logind;
// hypridle lo respeta vía ignore_systemd_inhibit = false.
//
// No se usa gdbus/org.freedesktop.ScreenSaver porque el cookie de Inhibit
// muere con la conexión del proceso que llama (NameOwnerChanged en hypridle);
// un proceso de corta vida se auto-desinhibe al instante.
Singleton {
    id: root

    property bool active: false

    readonly property bool enabled: root.active

    function toggle() {
        if (root.enabled) root.disable()
        else root.enable()
    }

    function enable() {
        if (root.enabled) return
        root.active = true
        process.command = [
            "/usr/sbin/systemd-inhibit",
            "--what=idle",
            "--mode=block",
            "--who=quickshell",
            "--why=Idle inhibitor (bar widget)",
            "/usr/bin/sleep", "infinity"
        ]
        process.running = true
    }

    function disable() {
        if (!root.enabled) return
        root.active = false
        process.signal(15) // SIGTERM
    }

    Process {
        id: process

        onExited: (code, status) => {
            if (root.active) root.active = false
        }
    }
}
