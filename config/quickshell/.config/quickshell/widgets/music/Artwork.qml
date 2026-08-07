// widgets/music/Artwork.qml
import QtQuick
import qs.globals

// Carátula con crossfade. Si no hay arte (p. ej. Chromium no expone
// mpris:artUrl) muestra un gradiente con glifo de música.
Item {
    id: root

    property string source: ""
    property int radius: AppTheme.musicArtRadius

    readonly property bool loaded: image.status === Image.Ready

    Rectangle {
        id: holder
        anchors.fill: parent
        radius: root.radius
        color: AppTheme.musicSurface
        border.width: 1
        border.color: AppTheme.borderColor
        clip: true

        Image {
            id: image
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: root.source
            asynchronous: true
            smooth: true
            opacity: 0
            visible: root.source.length > 0

            onStatusChanged: {
                if (status === Image.Ready) fadeIn.restart();
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.source.length === 0 || image.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(AppTheme.musicAccent, 0.4) }
                GradientStop { position: 1.0; color: Qt.alpha(AppTheme.color4, 0.25) }
            }

            Text {
                anchors.centerIn: parent
                text: "󰎆"
                font.family: AppTheme.fontMono
                font.pixelSize: Math.max(12, root.height * 0.4)
                color: Qt.alpha(AppTheme.fg, 0.7)
            }
        }
    }

    ParallelAnimation {
        id: fadeIn
        NumberAnimation {
            target: image; property: "opacity"; to: 1;
            duration: 220; easing.type: Easing.OutCubic
        }
    }

    onSourceChanged: image.opacity = 0
}
