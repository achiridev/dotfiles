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
    // `spinToken` se incrementa al empezar a buscar → los engranajes hacen el
    // "spin" de arrastre; `microToken` se incrementa en cada re-ajuste.
    // ============================================================
    property bool searching: false
    property int spinToken: 0
    property int microToken: 0
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
    property int hoverTooth: -1

    function toggle() {
        root.open = !root.open;
    }

    function close() {
        root.open = false;
    }

    function beginSearch() {
        root.searching = true;
        root.spinToken = (root.spinToken + 1) % 100000;
    }

    // Micro re-ajuste tras cada tecla (resultado cambia de posición).
    function touchSearch() {
        root.microToken = (root.microToken + 1) % 100000;
    }

    function endSearch() {
        root.searching = false;
    }

    function rotate(delta) {
        AppModel.navigate(delta);
        root.hoverTooth = -1;
    }

    function page(delta) {
        AppModel.jump(delta * root.gearSize);
        root.hoverTooth = -1;
    }

    // ============================================================
    // HOOKS DE ESTADO (pared entre SearchEngine y los widgets)
    // ============================================================
    onSearchingChanged: {
        if (!root.searching) {
            SearchEngine.clear();
            root.spinToken = 0;
            root.microToken = 0;
        }
    }
}
