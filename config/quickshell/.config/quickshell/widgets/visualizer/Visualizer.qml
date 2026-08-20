// widgets/visualizer/Visualizer.qml
import QtQuick

import qs.globals
import qs.services

Item {
    id: root
    anchors.fill: parent

    readonly property real barSpacing: 6
    readonly property real barWidth: (width - (CavaService.barCount - 1) * barSpacing) / CavaService.barCount

    Row {
        anchors.fill: parent
        spacing: root.barSpacing

        Repeater {
            model: CavaService.barCount

            delegate: Item {
                required property int index
                width: root.barWidth
                height: parent.height
                anchors.bottom: parent.bottom

                // Rectangle sólido sin capas/máscaras (patrón "bars" de
                // end-4/dots-hyprland): un solo draw call por barra y ningún
                // FBO. Sin Behavior: cava ya suaviza (noise_reduction) y el
                // servicio commitea a 30 fps.
                Rectangle {
                    width: parent.width
                    radius: width / 8
                    anchors.bottom: parent.bottom
                    color: Qt.alpha(AppTheme.color4, 0.9)

                    // El "* 1.5" permite que la barra suba más alto sin pegarse al techo.
                    height: Math.min(parent.height, Math.max(2, (CavaService.bars[index] / 100) * parent.height * 1.5))
                }
            }
        }
    }
}
