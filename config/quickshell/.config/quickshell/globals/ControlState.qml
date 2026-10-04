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
    property bool notificationsEnabled: true

    // ============================================================
    // VISIBILIDAD DEL PANEL DE CONTROL (ventana flotante)
    // El panel no se cierra por pérdida de foco ni se auto-desactiva:
    // solo se cierra explícitamente (botón o atajo).
    // ============================================================
    property bool panelOpen: false

    function togglePanel() { root.panelOpen = !root.panelOpen }
    function openPanel() { root.panelOpen = true }
    function closePanel() { root.panelOpen = false }

    // ============================================================
    // NAVEGACIÓN DE SECCIONES DEL PANEL DE CONTROL
    // El panel es un centro de control con varias secciones; solo se
    // muestra una a la vez (StackLayout en ControlPanel). Índices:
    //   0 = Componentes  1 = Colores (Wallust)  2 = Energía
    // ============================================================
    property int panelSection: 0

    // Abre el panel directamente en una sección concreta.
    function openSection(index) {
        root.panelSection = index
        root.openPanel()
    }
    function setSection(index) { root.panelSection = index }

    // Modo previo de la marca de agua "Activar Linux": al desactivar Activate
    // se fuerza activateMode=0 y se guarda el anterior para restaurarlo al
    // reactivar (la ventana solo se muestra si activateMode > 0).
    // Se inicializa una única vez en Component.onCompleted (no como binding,
    // para que el valor guardado no se pise al cambiar activateMode).
    property int savedActivateMode: 2

    Component.onCompleted: {
        root.savedActivateMode = AppState.activateMode
        root._applySettings()
    }

    // SettingsService lee settings.json de forma asíncrona, así que puede
    // terminar DESPUÉS de este Component.onCompleted. Cuando termine de leer,
    // se re-aplica el estado guardado.
    Connections {
        target: SettingsService
        function onReadyChanged() {
            if (SettingsService.ready) root._applySettings()
        }
    }

    function _applySettings() {
        if (!SettingsService.ready) return
        root.barEnabled = SettingsService.barEnabled
        root.overviewEnabled = SettingsService.overviewEnabled
        root.wallpapersEnabled = SettingsService.wallpapersEnabled
        root.launcherEnabled = SettingsService.launcherEnabled
        root.activateEnabled = SettingsService.activateEnabled
        root.visualizerEnabled = SettingsService.visualizerEnabled
        root.notificationsEnabled = SettingsService.notificationsEnabled
    }

    // ============================================================
    // AL CAMBIAR UN COMPONENTE, persistir el nuevo estado y, si se desactivó,
    // cerrar su ventana si estuviera abierta.
    // ============================================================
    onBarEnabledChanged: {
        SettingsService.barEnabled = root.barEnabled
        SettingsService.scheduleSave()
    }
    onOverviewEnabledChanged: {
        if (!root.overviewEnabled) OverviewService.close()
        SettingsService.overviewEnabled = root.overviewEnabled
        SettingsService.scheduleSave()
    }
    onWallpapersEnabledChanged: {
        if (!root.wallpapersEnabled) WallpaperService.close()
        SettingsService.wallpapersEnabled = root.wallpapersEnabled
        SettingsService.scheduleSave()
    }
    onLauncherEnabledChanged: {
        if (!root.launcherEnabled) LauncherState.close()
        SettingsService.launcherEnabled = root.launcherEnabled
        SettingsService.scheduleSave()
    }
    onActivateEnabledChanged: {
        if (!root.activateEnabled) {
            root.savedActivateMode = AppState.activateMode
            AppState.activateMode = 0
        } else {
            AppState.activateMode = root.savedActivateMode > 0 ? root.savedActivateMode : 2
        }
        SettingsService.activateEnabled = root.activateEnabled
        SettingsService.scheduleSave()
    }
    // Ya no hay ventana de centro de notificaciones que cerrar; el popup de
    // hover se gestiona solo con visible + el HoverHandler de la campana.
    onVisualizerEnabledChanged: {
        SettingsService.visualizerEnabled = root.visualizerEnabled
        SettingsService.scheduleSave()
    }
    onNotificationsEnabledChanged: {
        SettingsService.notificationsEnabled = root.notificationsEnabled
        SettingsService.scheduleSave()
    }
}
