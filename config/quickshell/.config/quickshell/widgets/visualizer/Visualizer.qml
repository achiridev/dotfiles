// widgets/visualizer/Visualizer.qml
import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects

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

                // Rectángulo base que define la animación de altura
                Rectangle {
                    id: barRect
                    width: parent.width
                    radius: width / 8
                    anchors.bottom: parent.bottom

                    // El "* 1.5" permite que la barra suba más alto sin pegarse al techo.
                    height: Math.min(parent.height, Math.max(2, (CavaService.bars[index] / 100) * parent.height * 1.5))

                    opacity: 0

                    Behavior on height {
                        NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                    }
                }

                // Gradiente de las barras
                LinearGradient {
                    anchors.fill: barRect
                    source: barRect
                    start: Qt.point(0, barRect.height)
                    end: Qt.point(0, 0)

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(AppTheme.color5, 0.6) }
                        GradientStop { position: 0.5; color: Qt.alpha(AppTheme.color4, 0.75) }
                        GradientStop { position: 1.0; color: Qt.alpha(AppTheme.color3, 0.9) }
                    }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: barRect.width
                            height: barRect.height
                            radius: barRect.radius
                        }
                    }
                }
            }
        }
    }
}
