// globals/ControlState.qml
// Estado global del Panel de Control de componentes de Quickshell.
// Cada componente se monta/desmonta desde shell.qml mediante un Loader activo
// cuando su flag `*Enabled` es true. Desmontar destruye su PanelWindow/surface
// (libera RAM de verdad), no solo la oculta.
// Este singleton SIEMPRE vive cargado: el panel de control es permanente y no
// se puede auto-desactivar.
pragma Singleton
import QtQuick
import Quickshell
import qs.globals
import qs.services

Singleton {
    id: root

    // ============================================================
    // ESTADO DE ACTIVACIÓN DE CADA COMPONENTE
    // (por defecto todos activos; el estado no persiste entre sesiones)
    // ============================================================
    property bool barEnabled: true
    property bool overviewEnabled: true
    property bool wallpapersEnabled: true
    property bool launcherEnabled: true
    property bool activateEnabled: true
    property bool visualizerEnabled: true

    // ============================================================
    // VISIBILIDAD DEL PANEL DE CONTROL (ventana flotante)
    // El panel no se cierra por pérdida de foco ni se auto-desactiva:
    // solo se cierra explícitamente (botón o atajo).
    // ============================================================
    property bool panelOpen: false

    function togglePanel() { root.panelOpen = !root.panelOpen }
    function openPanel() { root.panelOpen = true }
    function closePanel() { root.panelOpen = false }

    // Modo previo de la marca de agua "Activar Linux": al desactivar Activate
    // se fuerza activateMode=0 y se guarda el anterior para restaurarlo al
    // reactivar (la ventana solo se muestra si activateMode > 0).
    // Se inicializa una única vez en Component.onCompleted (no como binding,
    // para que el valor guardado no se pise al cambiar activateMode).
    property int savedActivateMode: 2

    Component.onCompleted: {
        root.savedActivateMode = AppState.activateMode
    }

    // ============================================================
    // AL DESACTIVAR UN COMPONENTE, cerrar su ventana si estuviera abierta
    // ============================================================
    onOverviewEnabledChanged: {
        if (!root.overviewEnabled) OverviewService.close()
    }
    onWallpapersEnabledChanged: {
        if (!root.wallpapersEnabled) WallpaperService.close()
    }
    onLauncherEnabledChanged: {
        if (!root.launcherEnabled) LauncherState.close()
    }
    onActivateEnabledChanged: {
        if (!root.activateEnabled) {
            root.savedActivateMode = AppState.activateMode
            AppState.activateMode = 0
        } else {
            AppState.activateMode = root.savedActivateMode > 0 ? root.savedActivateMode : 2
        }
    }
}
