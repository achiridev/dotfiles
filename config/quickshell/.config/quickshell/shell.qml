// shell.qml - Entry point de Quickshell
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.globals
import qs.windows.bar
import qs.windows.control
import qs.windows.visualizer
import qs.windows.overview
import qs.windows.wallpapers
import qs.windows.launcher
import qs.windows.activate
import qs.widgets.notifications

ShellRoot {
    // Cada componente se monta/desmonta según ControlState.<x>Enabled.
    // Loader con active:false DESTRUYE la instancia (PanelWindow/surface),
    // liberando RAM de verdad. El ControlPanel siempre queda montado.
    Loader {
        active: ControlState.barEnabled
        sourceComponent: Bar {}
    }

    // Toast host: per-monitor (NotificationToastHost maneja Variants internamente)
    Loader {
        id: toastHostLoader
        active: ControlState.notificationsEnabled
        sourceComponent: NotificationToastHost {}
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Loader {
                id: visualizerLoader
                active: ControlState.visualizerEnabled
                // Variants inyecta `modelData` (el monitor) a la raíz del
                // delegate. La reenviamos a la ventana instanciada al cargar.
                property var modelData: undefined
                sourceComponent: VisualizerWindow {}
                onLoaded: {
                    if (item) item.screen = visualizerLoader.modelData
                }
            }
        }
    }

    Loader {
        active: ControlState.overviewEnabled
        sourceComponent: Overview {}
    }
    Loader {
        active: ControlState.wallpapersEnabled
        sourceComponent: WallpapersWindow {}
    }
    Loader {
        active: ControlState.launcherEnabled
        sourceComponent: LauncherWindow {}
    }
    Loader {
        active: ControlState.activateEnabled
        sourceComponent: ActivateWindow {}
    }
    // No hay ventana de centro de notificaciones: se eliminó. El daemon
    // sigue vivo (services/NotificationsService.qml) y la UI es el popup de
    // hover de la campana (widgets/notifications/NotificationCenterPopup.qml).

    // Panel de control: PERMANENTE, no se desactiva.
    ControlPanel {}
}
