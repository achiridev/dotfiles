import QtQuick
import Quickshell
import qs.globals
import qs.services
// globals/LauncherState.qml
// Estado global del launcher Gear: ventana (open/toggle), fase de búsqueda,
// geometría/métricas del engranaje y acciones de navegación del anillo.
pragma Singleton

Singleton {
    id: root

    // ============================================================
    // VENTANA
    // ============================================================
    property bool open: false
    // ============================================================
    // BÚSQUEDA (estado visual)
    // `searching` true mientras se escribe; dispara el "spin" de arrastre.
    // ============================================================
    property bool searching: false
    // ============================================================
    // GEOMETRÍA DEL ENGRANAJE (tunables)
    // gearSize: estaciones de la corona; el DIENTE SUPERIOR (index 0, ángulo
    // -90°) es el foco (diente k muestra ring[mod(offset + k, count)]).
    // Rotación de reasentamiento: step * (offset % gearSize) → "clic de
    // trinquete" de la rueda completa por paso de navegación.
    // ============================================================
    readonly property int gearSize: AppTheme.launcherGearStations
    readonly property int satelliteCount: AppTheme.launcherSatellites
    readonly property real step: 360 / root.gearSize
    readonly property int toothCount: root.gearSize // corona completa (8), la superior = foco
    // ============================================================
    // NAVEGACIÓN (delega en AppModel)
    // ============================================================

    function toggle() {
        root.open = !root.open;
    }

    function close() {
        root.open = false;
    }

    function beginSearch() {
        root.searching = true;
    }

    function endSearch() {
        root.searching = false;
    }

    function rotate(delta) {
        AppModel.navigate(delta);
    }

    function page(delta) {
        AppModel.jump(delta * root.gearSize);
    }

    // ============================================================
    // HOOKS DE ESTADO (pared entre SearchEngine y los widgets)
    // ============================================================
    onSearchingChanged: {
        if (!root.searching) {
            SearchEngine.clear();
        }
    }
}
