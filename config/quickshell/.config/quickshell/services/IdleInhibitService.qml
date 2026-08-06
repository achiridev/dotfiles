// services/IdleInhibitService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Inhibidor de inactividad vía D-Bus (org.freedesktop.ScreenSaver).
// hypridle respeta esta interfaz (ignore_dbus_inhibit = false), mientras
// que el protocolo wayland zwp_idle_inhibit_v1 no frena su dpms/lock.
Singleton {
    id: root

    readonly property string dbusService: "org.freedesktop.ScreenSaver"
    readonly property string dbusPath: "/org/freedesktop/ScreenSaver"
    readonly property string dbusMethod: "org.freedesktop.ScreenSaver"

    property int cookie: -1
    property string pendingCall: ""

    readonly property bool enabled: root.cookie >= 0

    function toggle() {
        if (root.enabled) root.disable()
        else root.enable()
    }

    function enable() {
        if (root.enabled) return
        root.pendingCall = "inhibit"
        process.command = [
            "gdbus", "call", "--session",
            "--dest", root.dbusService,
            "--object-path", root.dbusPath,
            "--method", root.dbusMethod + ".Inhibit",
            "quickshell", "idle-inhibitor"
        ]
        process.running = true
    }

    function disable() {
        if (!root.enabled) return
        root.pendingCall = "uninhibit"
        process.command = [
            "gdbus", "call", "--session",
            "--dest", root.dbusService,
            "--object-path", root.dbusPath,
            "--method", root.dbusMethod + ".UnInhibit",
            String(root.cookie)
        ]
        process.running = true
    }

    Process {
        id: process

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (!data) return

                if (root.pendingCall === "inhibit") {
                    const match = data.match(/uint32\s+(\d+)/)
                    if (match) root.cookie = parseInt(match[1], 10)
                } else if (root.pendingCall === "uninhibit") {
                    root.cookie = -1
                }

                root.pendingCall = ""
            }
        }

        onExited: (code, status) => {
            if (root.pendingCall !== "") root.pendingCall = ""
        }
    }
}
