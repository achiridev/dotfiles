// widgets/music/Music.qml
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.globals
import qs.services
import qs.widgets.music

Item {
    id: root

    implicitWidth: box.implicitWidth
    implicitHeight: AppTheme.heightBar

    property bool popupOpen: false

    // HoverHandler reporta hover sin robar eventos de los MouseArea hijos.
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool shouldOpen: hovered || popup.hovered
    readonly property bool hasPlayer: MprisService.activePlayer !== null

    onShouldOpenChanged: {
        if (root.shouldOpen) {
            closeTimer.stop()
            root.popupOpen = true
        } else {
            closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: 150
        onTriggered: root.popupOpen = false
    }

    HoverHandler {
        id: hoverHandler
    }

    Rectangle {
        id: box

        anchors.fill: parent
        implicitWidth: content.implicitWidth + AppTheme.paddingBase * 2
        radius: AppTheme.radius
        border.width: 1
        border.color: AppTheme.borderColor
        color: root.hovered ? AppTheme.bgModuleHover : AppTheme.bgModule

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: AppTheme.paddingSmall

            // ---------- Estado idle: solo glifo ----------
            Text {
                visible: !root.hasPlayer
                text: "󰎆"
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.musicAccentDim
            }

            // ---------- Estado activo: carátula + título + ecualizador ----------
            Artwork {
                visible: root.hasPlayer
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 5
                source: MprisService.effectiveArtUrl
            }

            Text {
                visible: root.hasPlayer
                Layout.preferredWidth: 132
                text: MprisService.activeTrack.title
                elide: Text.ElideRight
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.fg
            }

            // Ecualizador pulsante mientras reproduce
            Row {
                visible: root.hasPlayer
                spacing: 2
                Layout.preferredHeight: 14

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index

                        property bool active: MprisService.isPlaying
                        property int minH: 4 + index * 1
                        property int maxH: 12 - index * 2

                        width: 2
                        radius: 1
                        color: AppTheme.musicAccent
                        anchors.bottom: parent.bottom
                        height: 6
                        opacity: MprisService.isPlaying ? 1 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        onActiveChanged: if (!active) height = 6

                        SequentialAnimation on height {
                            running: active
                            loops: Animation.Infinite
                            PropertyAction { value: minH }
                            NumberAnimation { to: maxH; duration: 260; easing.type: Easing.InOutSine }
                            NumberAnimation { to: minH; duration: 260; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.popupOpen = true
            } else if (mouse.button === Qt.RightButton) {
                MprisService.openYouTubeMusic()
            } else if (mouse.button === Qt.MiddleButton) {
                MprisService.togglePlaying()
            }
        }

        onWheel: (wheel) => {
            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            MprisService.setVolume(MprisService.volume + delta)
        }
    }

    MusicPopup {
        id: popup
        anchorItem: root
        requestOpen: root.popupOpen
    }
}
