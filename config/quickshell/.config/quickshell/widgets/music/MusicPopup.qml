// widgets/music/MusicPopup.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris

import qs.globals
import qs.services
import qs.widgets.volume
import qs.widgets.music

PopupWindow {
    id: popup

    property Item anchorItem
    // Estado deseado, lo maneja el padre (hover). La ventana se muestra con `shown`
    // para poder reproducir la animación de salida antes de ocultarse.
    property bool requestOpen: false
    property bool shown: false
    readonly property bool hovered: hoverHandler.hovered

    visible: shown

    onRequestOpenChanged: {
        if (requestOpen) {
            closeAnim.stop()
            if (shown) {
                // Volvió el mouse durante el cierre: reinicia la apertura.
                card.opacity = 0
                card.scale = 0.92
                card.y = 8
                openAnim.start()
            } else {
                shown = true
            }
        } else if (shown && !closeAnim.running) {
            closeAnim.start()
        }
    }

    onShownChanged: {
        if (shown) {
            card.opacity = 0
            card.scale = 0.92
            card.y = 8
            openAnim.start()
        }
    }

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? (anchorItem.width / 2 - implicitWidth / 2) : 0
    // Sin gap: el popup nace justo debajo del widget para que el hover sea continuo.
    anchor.rect.y: anchorItem ? anchorItem.height : 0
    anchor.adjustment: PopupAdjustment.Slide

    implicitWidth: 440
    implicitHeight: card.implicitHeight
    color: "transparent"

    Rectangle {
        id: card
        width: popup.implicitWidth
        implicitHeight: stack.implicitHeight + (AppTheme.paddingLarge + AppTheme.paddingSmall) * 2
        radius: AppTheme.radiusLarge
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(AppTheme.musicAccent, 0.16) }
            GradientStop { position: 0.4; color: AppTheme.bgPopup }
            GradientStop { position: 1.0; color: AppTheme.bgPopup }
        }
        border.width: 1
        border.color: AppTheme.borderColor
        transformOrigin: Item.Top
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        // Detecta hover de todo el popup sin interferir con los MouseArea internos.
        HoverHandler {
            id: hoverHandler
        }

        // ============ PÁGINAS: vacía <-> reproductor (crossfade) ============
        Item {
            id: stack
            anchors.fill: parent
            anchors.margins: AppTheme.paddingLarge + AppTheme.paddingSmall

            readonly property Item currentPage: MprisService.activePlayer ? contentPage : emptyPage

            implicitHeight: currentPage.implicitHeight

            // ---------- Estado vacío ----------
            ColumnLayout {
                id: emptyPage
                width: stack.width
                spacing: AppTheme.paddingBase
                opacity: stack.currentPage === emptyPage ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 88
                    radius: 44
                    color: Qt.alpha(AppTheme.musicAccent, 0.12)
                    border.width: 1
                    border.color: Qt.alpha(AppTheme.musicAccent, 0.28)

                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        font.family: AppTheme.fontMono
                        font.pixelSize: 46
                        color: AppTheme.musicAccent
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Nada reproduciéndose"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontLarge
                    font.weight: Font.Bold
                    color: AppTheme.fg
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Reproduce algo en YouTube Music y aparecerá aquí."
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textSecondary
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: AppTheme.paddingBase
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: emptyCta.implicitWidth + AppTheme.paddingLarge * 2
                    radius: 18
                    color: ctaHover.containsMouse ? AppTheme.musicAccent : Qt.alpha(AppTheme.musicAccent, 0.85)
                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    scale: ctaHover.pressed ? 0.96 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Text {
                        id: emptyCta
                        anchors.centerIn: parent
                        text: "Abrir YouTube Music"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        font.weight: Font.Bold
                        color: AppTheme.bg
                    }
                    MouseArea {
                        id: ctaHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisService.openYouTubeMusic()
                    }
                }
            }

            // ---------- Reproductor ----------
            Item {
                id: contentPage
                width: stack.width
                opacity: stack.currentPage === contentPage ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                implicitHeight: trackWrap.implicitHeight

                // Transición al cambiar de canción (slide + fade, dirección según reverse)
                Item {
                    id: trackWrap
                    width: contentPage.width
                    implicitHeight: layout.implicitHeight

                    ColumnLayout {
                        id: layout
                        width: trackWrap.width
                        spacing: AppTheme.paddingBase

                        // ============ HEADER ============
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: AppTheme.paddingBase

                            Artwork {
                                Layout.preferredWidth: 104
                                Layout.preferredHeight: 104
                                radius: AppTheme.radiusLarge
                                source: MprisService.effectiveArtUrl
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: AppTheme.paddingSmall

                                Text {
                                    Layout.fillWidth: true
                                    text: MprisService.activeTrack.title
                                    elide: Text.ElideRight
                                    font.family: AppTheme.fontLayout
                                    font.pixelSize: AppTheme.fontLarge
                                    font.weight: Font.Bold
                                    color: AppTheme.fg
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: [MprisService.activeTrack.artist,
                                           MprisService.activeTrack.album]
                                          .filter(s => s && s.length > 0)
                                          .join(" • ")
                                    elide: Text.ElideRight
                                    font.family: AppTheme.fontLayout
                                    font.pixelSize: AppTheme.fontSmall
                                    color: AppTheme.textSecondary
                                }
                            }

                            MusicButton {
                                Layout.alignment: Qt.AlignTop
                                size: 28
                                glyph: "󰈈"
                                glyphColor: AppTheme.textSecondary
                                onClicked: MprisService.focusPlayer()
                            }
                        }

                        // ============ PROGRESO ============
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            MusicSeekBar {
                                Layout.fillWidth: true
                                position: MprisService.position
                                length: MprisService.length
                                // Sin duración real (stream en vivo) no se puede buscar.
                                seekable: MprisService.canSeek && MprisService.positionSupported && MprisService.length > 0
                                onSeekRequested: (secs) => MprisService.seekTo(secs)
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: MprisService.positionLabel
                                    font.family: AppTheme.fontMono
                                    font.pixelSize: AppTheme.fontTiny
                                    color: AppTheme.textSecondary
                                }
                                Item { Layout.fillWidth: true }
                                // Stream en vivo (sin duración MPRIS): la barra no
                                // se puede arrastrar, se indica con un punto pulsante.
                                RowLayout {
                                    visible: !MprisService.lengthSupported
                                    spacing: 4
                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: AppTheme.critical
                                        SequentialAnimation on opacity {
                                            running: true
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 1.0; to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                                            NumberAnimation { from: 0.2; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                        }
                                    }
                                    Text {
                                        text: "EN VIVO"
                                        font.family: AppTheme.fontLayout
                                        font.pixelSize: AppTheme.fontTiny
                                        font.weight: Font.Bold
                                        color: AppTheme.critical
                                    }
                                }
                                Text {
                                    text: MprisService.lengthLabel
                                    visible: MprisService.lengthSupported
                                    font.family: AppTheme.fontMono
                                    font.pixelSize: AppTheme.fontTiny
                                    color: AppTheme.textSecondary
                                }
                            }
                        }

                        // ============ CONTROLES ============
                        // prev/play/next siempre centrados; shuffle y repeat solo
                        // si el player los soporta (zen no lo expone en MPRIS).
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: AppTheme.paddingSmall
                            spacing: AppTheme.paddingBase

                            Item {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 1
                                MusicButton {
                                    anchors.centerIn: parent
                                    size: 32
                                    visible: MprisService.shuffleSupported
                                    glyph: "󰒝"
                                    active: MprisService.shuffle
                                    onClicked: MprisService.toggleShuffle()
                                }
                            }

                            Item { Layout.fillWidth: true }

                            MusicButton {
                                size: 34
                                glyph: "󰒮"
                                enabled: MprisService.canGoPrevious
                                onClicked: MprisService.previous()
                            }

                            MusicButton {
                                size: 52
                                glyph: MprisService.isPlaying ? "󰏤" : "󰐊"
                                emphasized: true
                                enabled: MprisService.canTogglePlaying
                                onClicked: MprisService.togglePlaying()
                            }

                            MusicButton {
                                size: 34
                                glyph: "󰒭"
                                enabled: MprisService.canGoNext
                                onClicked: MprisService.next()
                            }

                            Item { Layout.fillWidth: true }

                            Item {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 1
                                MusicButton {
                                    anchors.centerIn: parent
                                    size: 32
                                    visible: MprisService.loopSupported
                                    glyph: MprisService.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                                    active: MprisService.loopState !== MprisLoopState.None
                                    onClicked: MprisService.cycleLoop()
                                }
                            }
                        }

                        // ============ VOLUMEN ============
                        // Volumen del sink (PipeWire): el volumen MPRIS de
                        // Firefox/Zen es ignorado por el player (bug de Mozilla),
                        // así que se controla el sink como en el popup de volumen.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: AppTheme.paddingBase

                            Text {
                                text: AudioService.volumeGlyph()
                                font.family: AppTheme.fontMono
                                font.pixelSize: 16
                                color: AudioService.muted ? AppTheme.textSecondary : AppTheme.musicAccent
                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AudioService.toggleMute()
                                }
                            }
                            VolumeSliderBar {
                                Layout.fillWidth: true
                                from: 0; to: AudioService.maxVolume
                                value: AudioService.volume
                                enabled: AudioService.sinkReady
                                fillColor: AppTheme.musicAccent
                                handleColor: AppTheme.musicAccent
                                onMoved: (v) => AudioService.setVolume(AudioService.sink, v)
                            }
                        }

                        // ============ FOOTER ============
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: AppTheme.paddingSmall

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Abrir YouTube Music 󰏌"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                color: openHover.containsMouse ? AppTheme.musicAccent : AppTheme.textSecondary
                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    id: openHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: MprisService.openYouTubeMusic()
                                }
                            }
                        }
                    }
                }

                // Animación de cambio de canción
                ParallelAnimation {
                    id: trackAnim
                    NumberAnimation {
                        target: trackWrap; property: "opacity"; to: 1;
                        duration: 220; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: trackWrap; property: "x"; to: 0;
                        duration: 220; easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // ============ ANIMACIONES DE ABRIR/CERRAR ============
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; to: 1;    duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale";   to: 1;    duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "y";       to: 0;    duration: 180; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: card; property: "opacity"; to: 0;    duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "scale";   to: 0.95; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "y";       to: 6;    duration: 140; easing.type: Easing.InCubic }
        onFinished: popup.shown = false
    }

    // ============ CAMBIO DE CANCIÓN (conectado al servicio) ============
    Connections {
        target: MprisService

        function onTrackChanged(reverse) {
            trackAnim.stop()
            trackWrap.opacity = 0
            trackWrap.x = reverse ? -16 : 16
            trackAnim.start()
        }
    }
}
