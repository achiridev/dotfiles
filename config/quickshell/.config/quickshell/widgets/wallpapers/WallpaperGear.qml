// widgets/wallpapers/WallpaperGear.qml
// Tablero de engranajes del picker de wallpapers: un patrón de columnas/filas
// (wpBoardCols × wpBoardRows) de mini-engranajes (WallpaperGearSlot), cada uno
// con la imagen de un wallpaper. El engranaje del CENTRO es el foco y se ve más
// grande. Al navegar con las flechas el contenido del tablero "fluye" una celda
// en la dirección de la flecha: cada wallpaper entra deslizando desde el
// engranaje vecino hasta la celda que le toca (el foco nuevo llega a la celda
// 3x2 físicamente, sin saltos) y, en paralelo, los dientes giran ("muerden").
import QtQuick
import Quickshell

import qs.globals
import qs.services

Item {
    id: root

    signal applyRequested(var item)
    signal menuRequested(var item, Item anchor)

    readonly property int cols: AppTheme.wpBoardCols
    readonly property int rows: AppTheme.wpBoardRows
    // Foco en la celda 3x2 (1-indexado): fila 2 para un tablero de 4 filas.
    readonly property int centerCol: Math.floor(root.cols / 2)
    readonly property int centerRow: Math.floor((root.rows - 1) / 2)
    readonly property real stepW: AppTheme.wpGearSlotW + AppTheme.wpBoardGap
    readonly property real stepH: AppTheme.wpGearSlotH + AppTheme.wpBoardGap
    readonly property real boardW: root.cols * root.stepW - AppTheme.wpBoardGap
    readonly property real boardH: root.rows * root.stepH - AppTheme.wpBoardGap

    // Offset previo (mutable): para calcular el delta en cada paso de foco.
    property int lastOffset: WallpaperService.offset

    implicitWidth: root.boardW
    implicitHeight: root.boardH

    // ---- Tablero: lattice de engranajes (sin caja, al aire) ----
    Item {
        anchors.centerIn: parent
        width: root.boardW
        height: root.boardH

        Repeater {
            id: slots
            model: root.cols * root.rows

            delegate: WallpaperGearSlot {
                required property int index
                readonly property int c: index % root.cols
                readonly property int r: Math.floor(index / root.cols)
                readonly property int d: (r - root.centerRow) * root.cols + (c - root.centerCol)

                x: root.centerCol * root.stepW + (c - root.centerCol) * root.stepW
                y: root.centerRow * root.stepH + (r - root.centerRow) * root.stepH
                item: WallpaperService.boardItem(d)
                isFocus: (c === root.centerCol && r === root.centerRow)
                onClicked: it => root.applyRequested(it)
                onContextRequested: (it, slotRef) => root.menuRequested(it, slotRef)
            }
        }
    }

    // ---- Al cambiar el foco: flujo del contenido + giro de dientes ----
    Connections {
        target: WallpaperService
        function onOffsetChanged() {
            const delta = WallpaperService.offset - root.lastOffset;
            root.lastOffset = WallpaperService.offset;
            if (delta === 0)
                return;
            // Descomposición CON SIGNO del delta en celdas (soporta deltas
            // negativos: ←/↑). IMPORTANTE: mod() no vale aquí — mapea -1 a
            // cols-1 y el contenido se iba a una esquina/otro lado.
            const dr = delta < 0 ? Math.ceil(delta / root.cols) : Math.floor(delta / root.cols);
            const dc = delta - dr * root.cols;
            // Dirección de entrada del contenido: el wallpaper nuevo viene del
            // engranaje vecino en contra del avance. Ej: ← (dc=-1) entra desde
            // la izquierda (-stepW) y desliza hacia el foco; ↓ (dr=+1) entra
            // desde abajo (+stepH) y sube hasta su celda.
            const fx = dc * root.stepW;
            const fy = dr * root.stepH;
            for (let i = 0; i < slots.count; ++i) {
                const slot = slots.itemAt(i);
                slot.flowFromX = fx;
                slot.flowFromY = fy;
                slot.biteStep(delta);
            }
        }
    }
}