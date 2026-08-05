import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.globals
import qs.widgets.volume

PopupWindow {
    id: popup

    property Item anchorItem
    // Estado deseado, lo maneja el padre (hover). La ventana se muestra con `shown`
    // para poder reproducir la animación de salida antes de ocultarse.
    property bool requestOpen: false
    property bool shown: false
    readonly property bool hovered: hoverHandler.hovered

    // ---- Estado del header según la pestaña activa ----
    readonly property string headerTitle: ["Salida", "Entrada", "Aplicaciones"][tabs.currentIndex]
    readonly property string headerSubtitle: {
        if (tabs.currentIndex === 0) return AudioService.sinkName
        if (tabs.currentIndex === 1) return AudioService.sourceName
        return ""
    }
    readonly property string headerGlyph: {
        if (tabs.currentIndex === 0) return AudioService.volumeGlyph()
        if (tabs.currentIndex === 1) return "󰍬"
        return "󰓇"
    }
    readonly property bool headerMuted: {
        if (tabs.currentIndex === 0) return AudioService.muted
        if (tabs.currentIndex === 1) return AudioService.micMuted
        return false
    }
    readonly property int headerPercent: {
        if (tabs.currentIndex === 0) return AudioService.volumePercent
        if (tabs.currentIndex === 1) return AudioService.micVolumePercent
        return 0
    }

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

    implicitWidth: 520
    implicitHeight: card.implicitHeight
    color: "transparent"

    Rectangle {
        id: card
        width: popup.implicitWidth
        implicitHeight: layout.implicitHeight + (AppTheme.paddingLarge + AppTheme.paddingSmall) * 2
        radius: AppTheme.radiusLarge
        color: AppTheme.bgPopup
        border.width: 1
        border.color: AppTheme.borderColor
        transformOrigin: Item.Top

        // Detecta hover de todo el popup sin interferir con los MouseArea internos.
        HoverHandler {
            id: hoverHandler
        }

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: AppTheme.paddingLarge + AppTheme.paddingSmall
            spacing: AppTheme.paddingBase

            // ================= HEADER (control maestro) =================
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                Text {
                    text: popup.headerGlyph
                    font.family: AppTheme.fontMono
                    font.pixelSize: 26
                    color: popup.headerMuted ? AppTheme.critical : AppTheme.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: popup.headerTitle
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        font.weight: Font.Bold
                        color: AppTheme.fg
                    }
                    Text {
                        Layout.fillWidth: true
                        text: popup.headerSubtitle
                        elide: Text.ElideRight
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.textSecondary
                        visible: text.length > 0
                    }
                }

                Text {
                    text: popup.headerPercent + "%"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontLarge
                    font.weight: Font.Bold
                    color: popup.headerMuted ? AppTheme.critical : AppTheme.accent
                    visible: tabs.currentIndex !== 2
                }

                Rectangle {
                    visible: tabs.currentIndex !== 2
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    border.width: 1
                    border.color: Qt.alpha(AppTheme.fg, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: popup.headerMuted ? "󰝟" : "󰕾"
                        font.family: AppTheme.fontMono
                        font.pixelSize: 18
                        color: popup.headerMuted ? AppTheme.critical : AppTheme.success
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (tabs.currentIndex === 0) AudioService.toggleMute()
                            else if (tabs.currentIndex === 1) AudioService.toggleMicMute()
                        }
                    }
                }
            }

            // Slider maestro (solo en Salida / Entrada).
            VolumeSliderBar {
                Layout.fillWidth: true
                visible: tabs.currentIndex !== 2
                from: 0; to: AudioService.maxVolume
                value: tabs.currentIndex === 0 ? AudioService.volume : AudioService.micVolume
                enabled: tabs.currentIndex === 0 ? AudioService.sinkReady : AudioService.sourceReady
                fillColor: popup.headerMuted ? AppTheme.critical : AppTheme.accent
                handleColor: popup.headerMuted ? AppTheme.critical : AppTheme.accent
                onMoved: (v) => {
                    if (tabs.currentIndex === 0) AudioService.setVolume(AudioService.sink, v)
                    else AudioService.setVolume(AudioService.source, v)
                }
            }

            // ================= TABS =================
            RowLayout {
                spacing: AppTheme.paddingSmall
                Layout.topMargin: AppTheme.paddingSmall
                Repeater {
                    model: ["Salida", "Entrada", "Apps"]
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: AppTheme.radiusLarge
                        color: {
                            if (tabs.currentIndex === index) return AppTheme.accent
                            return tabMouse.containsMouse ? AppTheme.surface : "transparent"
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            font.weight: Font.Bold
                            color: tabs.currentIndex === index ? AppTheme.bg : AppTheme.fg
                        }
                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tabs.currentIndex = index
                        }
                    }
                }
            }

            // ================= PÁGINAS (transición crossfade + slide) =================
            Item {
                id: tabs
                Layout.fillWidth: true
                Layout.preferredHeight: currentPage.implicitHeight
                clip: true

                property int currentIndex: 0
                readonly property Item currentPage: currentIndex === 0 ? outputTab : currentIndex === 1 ? inputTab : appsTab

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                // ---------- SALIDA ----------
                ColumnLayout {
                    id: outputTab
                    spacing: AppTheme.paddingBase
                    width: tabs.width
                    opacity: tabs.currentIndex === 0 ? 1 : 0
                    y: tabs.currentIndex === 0 ? 0 : 12
                    z: tabs.currentIndex === 0 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    SectionHeader { text: "Dispositivos de salida" }
                    EmptyState {
                        visible: AudioService.sinks.length === 0
                        text: "Sin dispositivos de salida"
                    }
                    Repeater {
                        model: AudioService.sinks
                        delegate: DeviceEntry {
                            required property var modelData
                            node: modelData
                            isDefault: AudioService.sink === modelData
                            onSelectRequested: AudioService.setDefaultSink(modelData)
                        }
                    }
                }

                // ---------- ENTRADA ----------
                ColumnLayout {
                    id: inputTab
                    spacing: AppTheme.paddingBase
                    width: tabs.width
                    opacity: tabs.currentIndex === 1 ? 1 : 0
                    y: tabs.currentIndex === 1 ? 0 : 12
                    z: tabs.currentIndex === 1 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    SectionHeader { text: "Dispositivos de entrada" }
                    EmptyState {
                        visible: AudioService.sources.length === 0
                        text: "Sin dispositivos de entrada"
                    }
                    Repeater {
                        model: AudioService.sources
                        delegate: DeviceEntry {
                            required property var modelData
                            node: modelData
                            isDefault: AudioService.source === modelData
                            onSelectRequested: AudioService.setDefaultSource(modelData)
                        }
                    }
                }

                // ---------- APPS (mixer completo, con scroll) ----------
                ColumnLayout {
                    id: appsTab
                    spacing: AppTheme.paddingBase
                    width: tabs.width
                    opacity: tabs.currentIndex === 2 ? 1 : 0
                    y: tabs.currentIndex === 2 ? 0 : 12
                    z: tabs.currentIndex === 2 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(appsContent.implicitHeight, 480)
                        contentHeight: appsContent.implicitHeight
                        clip: true

                        ScrollBar.vertical: ScrollBar {
                            width: 5
                            policy: ScrollBar.AsNeeded
                            interactive: false
                            contentItem: Rectangle {
                                implicitWidth: 5
                                implicitHeight: 100
                                radius: 2
                                color: Qt.alpha(AppTheme.fg, 0.4)
                            }
                        }

                        ColumnLayout {
                            id: appsContent
                            width: parent.width
                            spacing: AppTheme.paddingBase

                            SectionHeader { text: "Reproduciendo" }
                            EmptyState {
                                visible: AudioService.playbackStreams.length === 0
                                text: "Ninguna app reproduciendo audio"
                            }
                            Repeater {
                                model: AudioService.playbackStreams
                                delegate: MixerEntry {
                                    required property var modelData
                                    node: modelData
                                }
                            }

                            SectionHeader {
                                text: "Grabando"
                                topMargin: AppTheme.paddingBase
                            }
                            EmptyState {
                                visible: AudioService.recordingStreams.length === 0
                                text: "Nada usando el micrófono"
                            }
                            Repeater {
                                model: AudioService.recordingStreams
                                delegate: MixerEntry {
                                    required property var modelData
                                    node: modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Apertura: fade + escala + slide desde la barra (crece hacia abajo).
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; to: 1;    duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale";   to: 1;    duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "y";       to: 0;    duration: 180; easing.type: Easing.OutCubic }
    }

    // Cierre: se oculta la ventana recién cuando termina la animación.
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: card; property: "opacity"; to: 0;    duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "scale";   to: 0.95; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "y";       to: 6;    duration: 140; easing.type: Easing.InCubic }
        onFinished: popup.shown = false
    }
}
