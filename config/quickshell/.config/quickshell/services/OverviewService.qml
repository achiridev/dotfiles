// services/OverviewService.qml
// Estado global del workspace overview + todos los dispatchers de Hyprland.
// Nota: Quickshell v0.3.0 calcula usingLua a partir de `hyprctl j/status`,
// endpoint que no existe en Hyprland 0.56 (devuelve "unknown request"), así
// que usingLua siempre es false aunque Hyprland corra en modo Lua. Los
// dispatchers se escriben en sintaxis Lua, que es la que funciona (igual que
// en WorkspacesService).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    property bool overviewOpen: false

    function open() { root.overviewOpen = true }
    function close() { root.overviewOpen = false }
    function toggle() { root.overviewOpen = !root.overviewOpen }

    function focusWorkspace(id) {
        Hyprland.dispatch(`hl.dsp.focus({workspace = ${id}})`);
    }

    function focusWindow(address) {
        Hyprland.dispatch(`hl.dsp.focus({window = 'address:${address}'})`);
    }

    function closeWindow(address) {
        Hyprland.dispatch(`hl.dsp.window.close('address:${address}')`);
    }

    function moveToWorkspace(address, id) {
        Hyprland.dispatch(`hl.dsp.window.move({workspace = ${id}, follow = false, window = 'address:${address}'})`);
    }

    function moveToSpecial(address, name) {
        Hyprland.dispatch(`hl.dsp.window.move({workspace = 'special:${name}', follow = false, window = 'address:${address}'})`);
    }

    function toggleSpecial(name) {
        Hyprland.dispatch(`hl.dsp.workspace.toggle_special('${name}')`);
    }
}
