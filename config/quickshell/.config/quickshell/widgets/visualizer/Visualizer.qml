// widgets/visualizer/Visualizer.qml
import QtQuick

import qs.globals
import qs.services

// Un solo Canvas pinta todas las barras en un único draw call por frame, en
// lugar de una Row + Repeater con N Rectangles (N draw calls + antialias por
// frame, N = CavaService.barCount). El look se replica: barras redondeadas,
// barSpacing fijo, barWidth proporcional y altura con tope "* 1.5".
Item {
    id: root
    anchors.fill: parent

    readonly property real barSpacing: 6
    readonly property real barWidth: (width - (CavaService.barCount - 1) * barSpacing) / CavaService.barCount
    readonly property color barColor: Qt.alpha(AppTheme.color4, 0.9)

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Immediate

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, canvas.width, canvas.height)

            const count = CavaService.barCount
            if (count <= 0 || canvas.height <= 0) return

            const spacing = root.barSpacing
            const bw = root.barWidth
            const h = canvas.height
            const radius = Math.max(2, Math.min(bw, h) / 8)

            ctx.fillStyle = root.barColor

            for (let i = 0; i < count; ++i) {
                const x = i * (bw + spacing)
                const bh = Math.min(h, Math.max(2, (CavaService.bars[i] / 100) * h * 1.5))
                ctx.beginPath()
                roundedRectPath(ctx, x, h - bh, bw, bh, radius)
                ctx.fill()
            }
        }

        // roundRect() del standard 2D solo existe en Qt 6.4+; la construimos a
        // mano con arcTo para no depender de la versión del runtime.
        function roundedRectPath(ctx, x, y, w, h, r) {
            r = Math.max(0, Math.min(r, w / 2, h / 2))
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w - r, y)
            ctx.arcTo(x + w, y, x + w, y + r, r)
            ctx.lineTo(x + w, y + h - r)
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
            ctx.lineTo(x + r, y + h)
            ctx.arcTo(x, y + h, x, y + h - r, r)
            ctx.lineTo(x, y + r)
            ctx.arcTo(x, y, x + r, y, r)
            ctx.closePath()
        }
    }

    // Repintar solo cuando cambia un frame, el color del tema o el tamaño.
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onBarColorChanged: canvas.requestPaint()

    Connections {
        target: CavaService
        function onBarsChanged() {
            canvas.requestPaint()
        }
    }
}
