// widgets/music/MusicButton.qml
import QtQuick
import qs.globals

// Botón circular para controles de reproducción.
//   - emphasized: relleno con color accent (play/pause principal)
//   - active: estado encendido (shuffle / repeat)
Rectangle {
    id: root

    property string glyph: ""
    property int size: 34
    property color glyphColor: AppTheme.fg
    property color accentColor: AppTheme.musicAccent
    property bool emphasized: false
    property bool active: false

    signal clicked()

    implicitWidth: root.size
    implicitHeight: root.size
    radius: root.size / 2

    opacity: root.enabled ? 1.0 : 0.35
    Behavior on opacity { NumberAnimation { duration: 150 } }

    color: {
        if (root.emphasized) return root.accentColor;
        if (root.hovered) return AppTheme.surface;
        return "transparent";
    }
    border.width: root.emphasized ? 0 : 1
    border.color: root.emphasized
        ? "transparent"
        : root.active ? Qt.alpha(root.accentColor, 0.6) : Qt.alpha(AppTheme.fg, 0.15)

    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

    scale: root.pressed ? 0.9 : root.hovered ? 1.1 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: AppTheme.fontMono
        font.pixelSize: root.size * 0.5
        color: root.emphasized ? AppTheme.bg : (root.active ? root.accentColor : root.glyphColor)

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
