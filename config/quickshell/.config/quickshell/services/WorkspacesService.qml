// services/WorkspacesService.qml
pragma Singleton
import Quickshell
import Quickshell.Hyprland

import qs.globals

Singleton
{
    readonly property int workspaceCount: 9

    function workspace(id) {
        return Hyprland.workspaces.values.find(ws => ws.id === id)
    }

    function exists(id) {
        return workspace(id) !== undefined
    }

    function isActive(id) {
        return Hyprland.focusedWorkspace?.id === id
    }

    function switchTo(id) {
        Hyprland.dispatch("workspace " + id)
    }

    function textColor(id) {

        if (isActive(id))
            return Theme.fg

        if (exists(id))
            return Qt.alpha(Theme.fg, 0.55)

        return Qt.alpha(Theme.fg, 0.35)
    }

    function background(id) {

        if (isActive(id))
            return Theme.color4
        if (exists(id))
            return Qt.alpha(Theme.color4, 0.35)
        return "transparent"
    }

    readonly property string backgroundHover: Theme.color5

    readonly property var visibleWorkspaces: {
        let ids = [];

        // Workspaces existentes
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 0)
                ids.push(ws.id);
        }

        const active = Hyprland.focusedWorkspace?.id;

        if (active) {

            // Workspace activa
            if (!ids.includes(active))
                ids.push(active);

            // Izquierda
            if (active > 1 && !ids.includes(active - 1))
                ids.push(active - 1);

            // Derecha
            if (!ids.includes(active + 1))
                ids.push(active + 1);
        }

        ids.sort((a, b) => a - b);

        return ids;
    }
}
