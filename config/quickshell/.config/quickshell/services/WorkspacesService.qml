// services/WorkspacesService.qml
pragma Singleton
import Quickshell
import Quickshell.Hyprland

import qs.globals

Singleton
{
    readonly property int activeWorkspaceId: Hyprland.focusedWorkspace?.id ?? -1

    // Obtenemos el workspace especial del monitor actual enfocado
    readonly property var specialWorkspace: Hyprland.focusedMonitor?.specialWorkspace
    // Limpiamos el nombre quitando "special:" (ej. "special:magic" -> "magic").
    // Si es null o indefinido, devolvemos un string vacío.
    readonly property string specialWorkspaceName: specialWorkspace?.name ? specialWorkspace.name.replace("special:", "") : ""
    // Si el nombre resultante no está vacío, el workspace especial está activo en pantalla
    readonly property bool isSpecialActive: specialWorkspaceName !== ""

    function exists(id) {
        if (id === "special") {
            return Hyprland.workspaces.values.find(ws =>
                ws.name === "special:magic"
            ) !== undefined
        }
        return Hyprland.workspaces.values.some(ws => ws.id === id);
    }

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
        if (direction > 0) {
            Hyprland.dispatch(`hl.dsp.focus({workspace = "r-1"})`);
        } else if (direction < 0) {
            Hyprland.dispatch(`hl.dsp.focus({workspace = "r+1"})`);
        }
    }

    readonly property string backgroundHover: Qt.alpha(AppTheme.color5, 0.9)

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