import QtQuick
import qs.globals

// Slider minimalista sin depender de QtQuick.Controls, para evitar
// los problemas de layout interno que rompían el drag en Slider nativo.
// Escalable: track/handle se derivan de la altura implícita y los colores
// son configurables por los callers.
Item {
    id: root

    property real from: 0
    property real to: 1.5
    property real value: 0
    property color trackColor: Qt.alpha(AppTheme.fg, 0.15)
    property color fillColor: AppTheme.accent
    property color handleColor: AppTheme.accent
    property bool enabled: true

    signal moved(real value)

    implicitHeight: 22

    function ratioFor(v) {
        if (to === from) return 0
        return Math.max(0, Math.min(1, (v - from) / (to - from)))
    }

    function valueForX(x) {
        const ratio = Math.max(0, Math.min(1, x / width))
        return from + ratio * (to - from)
    }

    opacity: enabled ? 1.0 : 0.4

    Behavior on fillColor { ColorAnimation { duration: 150 } }
    Behavior on handleColor { ColorAnimation { duration: 150 } }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: height / 2
        color: root.trackColor

        Rectangle {
            width: track.width * root.ratioFor(root.value)
            height: track.height
            radius: height / 2
            color: root.fillColor

            Behavior on width {
                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
            }
        }
    }

    Rectangle {
        id: handle
        width: 16
        height: 16
        radius: width / 2
        color: root.handleColor
        border.width: 1
        border.color: Qt.alpha(AppTheme.bg, 0.6)
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(root.width - width, track.width * root.ratioFor(root.value) - width / 2))

        scale: (hover.hovered || drag.pressed) ? 1.25 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on x {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: root.enabled
        onPressed: (mouse) => {
            root.value = root.valueForX(mouse.x)
            root.moved(root.value)
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                root.value = root.valueForX(mouse.x)
                root.moved(root.value)
            }
        }
    }
}
