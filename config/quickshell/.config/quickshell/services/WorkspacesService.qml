// services/WorkspacesService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs.globals

Singleton
{
    readonly property int activeWorkspaceId: Hyprland.focusedWorkspace?.id ?? -1

    // Hyprland 0.56 no emite eventos de socket al abrir un special workspace
    // y Quickshell v0.3.0 no expone specialWorkspace como propiedad del monitor,
    // así que leemos el IPC crudo (lastIpcObject) y forzamos refreshMonitors().
    readonly property var specialWorkspaceInfo: Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace
    // Limpiamos el nombre quitando "special:" (ej. "special:magic" -> "magic").
    readonly property string specialWorkspaceName: specialWorkspaceInfo?.name
        ? specialWorkspaceInfo.name.replace("special:", "") : ""
    // Si el nombre resultante no está vacío, el workspace especial está activo en pantalla
    readonly property bool isSpecialActive: specialWorkspaceName !== ""

    readonly property var refreshEvents: [
        "workspacev2", "activewindowv2", "focusedmon",
        "openwindow", "closewindow", "movewindowv2",
        "activespecial", "activespecialv2", "fullscreen",
        "createworkspacev2", "destroyworkspacev2", "configreloaded"
    ]

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (WorkspacesService.refreshEvents.includes(event.name))
                Hyprland.refreshMonitors()
        }
    }

    // La apertura de un special vacío no dispara ningún evento de socket;
    // este timer de respaldo garantiza que el estado activo siempre se actualice.
    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: Hyprland.refreshMonitors()
    }

    function exists(id) {
        if (id === "special") {
            return Hyprland.workspaces.values.find(ws =>
                ws.name === "special:magic"
            ) !== undefined
        }
        return Hyprland.workspaces.values.some(ws => ws.id === id);
    }

    // Nota: Quickshell v0.3.0 calcula usingLua a partir de `hyprctl j/status`,
    // endpoint que no existe en Hyprland 0.56 (devuelve "unknown request"), así
    // que usingLua siempre es false aunque Hyprland corra en modo Lua. Los
    // dispatchers se escriben en sintaxis Lua, que es la que funciona.
    function switchTo(id) {
        if (id === "special") {
            toggleSpecial()
            return;
        }
        Hyprland.dispatch(`hl.dsp.focus({workspace = ${id}})`);
    }

    function toggleSpecial() {
        Hyprland.dispatch(`hl.dsp.workspace.toggle_special("magic")`);
    }

    function scroll(direction) {
        const target = direction > 0 ? "r-1" : "r+1";
        Hyprland.dispatch(`hl.dsp.focus({workspace = "${target}"})`);
    }

    readonly property var visibleWorkspaces: {
        let ids = [];

        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 0) ids.push(ws.id);
        }

        const active = Hyprland.focusedWorkspace?.id;
        if (active && active > 0) {
            if (!ids.includes(active)) ids.push(active);
            if (active > 1 && !ids.includes(active - 1)) ids.push(active - 1);
            if (!ids.includes(active + 1)) ids.push(active + 1);
        }

        ids.sort((a, b) => a - b);
        ids.push("special");

        return ids;
    }
}
