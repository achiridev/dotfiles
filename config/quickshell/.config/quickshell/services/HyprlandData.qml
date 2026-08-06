// services/HyprlandData.qml
// Provee datos de Hyprland que Quickshell.Hyprland no expone (class, title,
// at/size, address, pinned, floating...) leyendo `hyprctl -j` con debounce.
// Adaptado de Shanu-Kumawat/quickshell-overview (services/HyprlandData.qml).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.globals

Singleton {
    id: root

    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var allWorkspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []

    property bool pendingWindowsUpdate: false
    property bool pendingMonitorsUpdate: false
    property bool pendingWorkspacesUpdate: false
    property bool pendingActiveWorkspaceUpdate: false

    function updateWindowList() { getClients.running = true }
    function updateMonitors() { getMonitors.running = true }
    function updateWorkspaces() { getWorkspaces.running = true; getActiveWorkspace.running = true }
    function updateAll() { root.scheduleUpdates(true, true, true, true) }

    // Los eventos del socket llegan a ráfagas; acumulamos qué refrescar y lo
    // despachamos tras un pequeño debounce para no saturar hyprctl.
    function scheduleUpdates(windows, monitors, workspaces, activeWorkspace) {
        root.pendingWindowsUpdate = root.pendingWindowsUpdate || !!windows
        root.pendingMonitorsUpdate = root.pendingMonitorsUpdate || !!monitors
        root.pendingWorkspacesUpdate = root.pendingWorkspacesUpdate || !!workspaces
        root.pendingActiveWorkspaceUpdate = root.pendingActiveWorkspaceUpdate || !!activeWorkspace
        eventDebounceTimer.restart()
    }

    function flushPendingUpdates() {
        if (root.pendingWindowsUpdate) {
            root.pendingWindowsUpdate = false
            root.updateWindowList()
        }
        if (root.pendingMonitorsUpdate) {
            root.pendingMonitorsUpdate = false
            root.updateMonitors()
        }
        if (root.pendingWorkspacesUpdate) {
            root.pendingWorkspacesUpdate = false
            root.updateWorkspaces()
        }
        if (root.pendingActiveWorkspaceUpdate) {
            root.pendingActiveWorkspaceUpdate = false
            getActiveWorkspace.running = true
        }
    }

    Component.onCompleted: {
        root.scheduleUpdates(true, true, true, true)
        root.flushPendingUpdates()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const eventName = `${event?.name ?? event?.event ?? event?.type ?? ""}`;
            if (["openlayer", "closelayer", "screencast"].includes(eventName))
                return;

            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle"].includes(eventName)) {
                root.scheduleUpdates(true, false, true, false)
                return
            }

            if (["workspace", "workspacev2", "focusedmon", "focusedmonv2", "activewindow", "activewindowv2"].includes(eventName)) {
                root.scheduleUpdates(false, false, true, true)
                return
            }

            if (eventName.startsWith("monitor") || eventName === "configreloaded") {
                root.scheduleUpdates(true, true, true, true)
                return
            }

            root.scheduleUpdates(true, true, true, true)
        }
    }

    Timer {
        id: eventDebounceTimer
        interval: AppTheme.overviewEventDebounceMs
        repeat: false
        onTriggered: root.flushPendingUpdates()
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.windowList = JSON.parse(clientsCollector.text)
                const tempWinByAddress = {}
                for (let i = 0; i < root.windowList.length; ++i) {
                    const win = root.windowList[i]
                    tempWinByAddress[win.address] = win
                }
                root.windowByAddress = tempWinByAddress
                root.addresses = root.windowList.map(win => win.address)
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text)
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                const rawWorkspaces = JSON.parse(workspacesCollector.text)
                root.allWorkspaces = rawWorkspaces
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100)
                const tempWorkspaceById = {}
                for (let i = 0; i < root.workspaces.length; ++i) {
                    const ws = root.workspaces[i]
                    tempWorkspaceById[ws.id] = ws
                }
                root.workspaceById = tempWorkspaceById
                root.workspaceIds = root.workspaces.map(ws => ws.id)
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text)
            }
        }
    }
}
