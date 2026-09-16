// widgets/wallpapers/WallpaperGear.qml
// Tablero de engranajes del picker: muestra TODOS los wallpapers visibles en
// una cuadrícula fija de `wpBoardCols` columnas × N filas (N depende de la
// cantidad). El foco empieza arriba-izquierda (1x1) y se mueve con las flechas
// (clamp, sin wrap); si las filas no caben, la cuadrícula hace scroll vertical.
// Al cambiar el foco, el engranaje focado "muerde" un paso: giro de dientes.
import QtQuick
import Quickshell

import qs.globals
import qs.services

Item {
    id: root

    signal applyRequested(var item)
    signal menuRequested(var item, Item anchor)

    readonly property int cols: AppTheme.wpBoardCols
    readonly property real gap: AppTheme.wpBoardGap
    // Celda dinámica: el tablero llena el ancho disponible con `cols` columnas,
    // sin superar `wpGearMaxCell` (si sobra, la rejilla queda centrada).
    readonly property real cellW: Math.max(24, Math.min((root.width - root.gap) / root.cols, AppTheme.wpGearMaxCell))
    readonly property real boardW: root.cols * root.cellW

    // Offset previo (mutable): para calcular el delta de paso del foco.
    property int lastOffset: WallpaperService.offset

    GridView {
        id: grid
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.boardW
        clip: true
        interactive: true
        cellWidth: root.cellW
        cellHeight: root.cellW
        model: WallpaperService.visibleItems
        cacheBuffer: root.cellW * 4
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            required property int index
            required property var modelData
            // OJO: `GridView.isCurrentItem` se adjunta a la RAÍZ del delegate;
            // leerlo dentro de un hijo devuelve siempre false.
            readonly property bool cellCurrent: GridView.isCurrentItem
            width: root.cellW
            height: root.cellW

            WallpaperGearSlot {
                id: gear
                anchors.centerIn: parent
                size: root.cellW - root.gap
                item: modelData
                isFocus: cellCurrent
                onClicked: it => {
                    grid.currentIndex = index
                    root.applyRequested(it)
                }
                onContextRequested: (it, anchor) => root.menuRequested(it, anchor)
            }

            function biteStep(delta) {
                gear.biteStep(delta)
            }
        }
    }

    // ---- Al cambiar el foco: giro del engranaje focado + scroll al foco ----
    Connections {
        target: WallpaperService
        function onOffsetChanged() {
            const delta = WallpaperService.offset - root.lastOffset;
            root.lastOffset = WallpaperService.offset;
            grid.currentIndex = WallpaperService.offset;
            grid.positionViewAtIndex(WallpaperService.offset, GridView.Center);
            if (delta !== 0) {
                const d = grid.currentItem;
                if (d && d.biteStep)
                    d.biteStep(delta);
            }
        }
    }
}