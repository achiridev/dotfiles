import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.globals

// Fila reutilizable para un stream de aplicación (Reproduciendo / Grabando):
// icono, nombre + subtítulo (media.name), porcentaje, toggle de mute y slider.
ColumnLayout {
    id: root

    required property var node

    Layout.fillWidth: true
    spacing: AppTheme.paddingSmall

    readonly property color _hoverBg: Qt.alpha(AppTheme.fg, 0.06)
    readonly property color _baseBg: Qt.alpha(AppTheme.fg, 0.03)
    readonly property bool _muted: node && node.audio ? node.audio.muted : false

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: appCol.implicitHeight + AppTheme.paddingLarge * 2
        radius: AppTheme.radius
        border.width: 1
        border.color: AppTheme.borderColor
        color: rowHover.hovered ? _hoverBg : _baseBg

        Behavior on color { ColorAnimation { duration: 150 } }

        HoverHandler {
            id: rowHover
        }

        ColumnLayout {
            id: appCol
            anchors.fill: parent
            anchors.margins: AppTheme.paddingLarge
            spacing: AppTheme.paddingBase

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32

                    IconImage {
                        id: appIcon
                        anchors.fill: parent
                        visible: source.length > 0
                        source: {
                            const iconName = AudioService.iconName(root.node)
                            return iconName ? Quickshell.iconPath(iconName, true) : ""
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: appIcon.source.length === 0
                        text: "󰎆"
                        font.family: AppTheme.fontMono
                        font.pixelSize: 24
                        color: AppTheme.textSecondary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: AudioService.displayName(root.node)
                        elide: Text.ElideRight
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        font.weight: Font.Medium
                        color: AppTheme.fg
                    }
                    Text {
                        Layout.fillWidth: true
                        text: AudioService.subtitle(root.node)
                        elide: Text.ElideRight
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.textSecondary
                        visible: text.length > 0
                    }
                }

                Text {
                    text: Math.round((root.node.audio ? root.node.audio.volume : 0) * 100) + "%"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontBase
                    font.weight: Font.Bold
                    color: root._muted ? AppTheme.textTertiary : AppTheme.fg
                    Layout.preferredWidth: 44
                }

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(AppTheme.fg, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: root._muted ? "󰝟" : "󰕾"
                        font.family: AppTheme.fontMono
                        font.pixelSize: 16
                        color: root._muted ? AppTheme.critical : AppTheme.success
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AudioService.toggleMuted(root.node)
                    }
                }
            }

            VolumeSliderBar {
                Layout.fillWidth: true
                from: 0; to: AudioService.maxVolume
                value: root.node.audio ? root.node.audio.volume : 0
                enabled: root.node && root.node.ready
                fillColor: root._muted ? AppTheme.critical : AppTheme.accent
                handleColor: root._muted ? AppTheme.critical : AppTheme.accent
                onMoved: (v) => AudioService.setVolume(root.node, v)
            }
        }
    }
}
