// widgets/music/MusicSeekBar.qml
import QtQuick
import qs.globals

// Barra de progreso arrastrable. Durante el drag muestra la posición
// local (sin pisar al player); al soltar emite seekRequested(segundos).
Item {
    id: root

    property real position: 0
    property real length: 0
    property bool seekable: false
    property color trackColor: Qt.alpha(AppTheme.fg, 0.15)
    property color fillColor: AppTheme.musicAccent
    property color fillColorBright: AppTheme.musicAccentBright
    property color handleColor: AppTheme.musicAccent

    signal seekRequested(real seconds)

    implicitHeight: 22

    // -1 = no arrastrando
    property real dragRatio: -1

    readonly property real ratio: root.length > 0
        ? Math.max(0, Math.min(1, root.position / root.length))
        : 0
    readonly property real displayedRatio: root.dragRatio >= 0 ? root.dragRatio : root.ratio

    opacity: root.seekable ? 1.0 : 0.45

    Behavior on fillColor { ColorAnimation { duration: 150 } }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: height / 2
        color: root.trackColor

        Rectangle {
            width: track.width * root.displayedRatio
            height: track.height
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.fillColor }
                GradientStop { position: 1.0; color: root.fillColorBright }
            }

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
        x: Math.max(0, Math.min(root.width - width,
            track.width * root.displayedRatio - width / 2))

        scale: (hover.hovered || drag.pressed) ? 1.25 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: root.seekable

        function updateFromX(x) {
            const r = Math.max(0, Math.min(1, x / root.width));
            root.dragRatio = r;
        }

        onPressed: (mouse) => {
            drag.updateFromX(mouse.x);
        }
        onPositionChanged: (mouse) => {
            if (pressed) drag.updateFromX(mouse.x);
        }
        onReleased: {
            if (root.dragRatio >= 0) {
                root.seekRequested(root.dragRatio * root.length);
            }
            root.dragRatio = -1;
        }
        onCanceled: root.dragRatio = -1
    }
}
