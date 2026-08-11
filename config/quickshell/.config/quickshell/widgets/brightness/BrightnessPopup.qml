// widgets/brightness/BrightnessPopup.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.globals
import qs.services
import qs.widgets.volume

// Popup de brillo: control de pantalla + teclado Acer RGB (escalable).
// El slider base es VolumeSliderBar (de qs.widgets.volume), que es genérico.
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
    anchor.rect.y: anchorItem ? anchorItem.height : 0
    anchor.adjustment: PopupAdjustment.Slide

    implicitWidth: 400
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

        HoverHandler {
            id: hoverHandler
        }

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: AppTheme.paddingLarge + AppTheme.paddingSmall
            spacing: AppTheme.paddingBase

            // ================= HEADER PANTALLA =================
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                Text {
                    text: BrightnessService.screenGlyph()
                    font.family: AppTheme.fontMono
                    font.pixelSize: 26
                    color: AppTheme.color3
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: "Brillo"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        font.weight: Font.Bold
                        color: AppTheme.fg
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Pantalla"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.textSecondary
                    }
                }

                Text {
                    text: BrightnessService.screenPercent + "%"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontLarge
                    font.weight: Font.Bold
                    color: AppTheme.color3
                }
            }

            // Slider maestro de pantalla.
            VolumeSliderBar {
                Layout.fillWidth: true
                from: 0; to: 1
                value: BrightnessService.screenBrightness
                enabled: BrightnessService.screenReady
                fillColor: AppTheme.color3
                handleColor: AppTheme.color3
                onMoved: (v) => BrightnessService.setScreen(v)
            }

            // ================= TECLADO (Acer RGB) =================
            ColumnLayout {
                Layout.fillWidth: true
                visible: BrightnessService.keyboardAvailable
                spacing: AppTheme.paddingBase

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: AppTheme.borderColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "󰌌"
                        font.family: AppTheme.fontMono
                        font.pixelSize: 24
                        color: AppTheme.accent
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: "Teclado"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            font.weight: Font.Bold
                            color: AppTheme.fg
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Brillo y RGB"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.textSecondary
                        }
                    }

                    Text {
                        text: BrightnessService.keyboardBrightness + "%"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontLarge
                        font.weight: Font.Bold
                        color: AppTheme.accent
                    }
                }

                VolumeSliderBar {
                    Layout.fillWidth: true
                    from: 0; to: 100
                    value: BrightnessService.keyboardBrightness
                    fillColor: AppTheme.accent
                    handleColor: AppTheme.accent
                    onMoved: (v) => BrightnessService.setKeyboardBrightness(v)
                }

                // Modos de efecto (facer_rgb.py -m)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: AppTheme.paddingSmall
                        Repeater {
                            model: [["Estático", 0], ["Respiración", 1], ["Neón", 2]]
                            delegate: modeBtn
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: AppTheme.paddingSmall
                        Repeater {
                            model: [["Ola", 3], ["Shifting", 4], ["Zoom", 5]]
                            delegate: modeBtn
                        }
                    }
                }

                // Colores RGB: sliders + swatches rápidos.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingSmall

                    VolumeSliderBar {
                        Layout.fillWidth: true
                        from: 0; to: 255
                        value: BrightnessService.keyboardRed
                        fillColor: AppTheme.color9
                        handleColor: AppTheme.color9
                        onMoved: (v) => BrightnessService.setKeyboardColor(v, BrightnessService.keyboardGreen, BrightnessService.keyboardBlue)
                    }
                    VolumeSliderBar {
                        Layout.fillWidth: true
                        from: 0; to: 255
                        value: BrightnessService.keyboardGreen
                        fillColor: AppTheme.color10
                        handleColor: AppTheme.color10
                        onMoved: (v) => BrightnessService.setKeyboardColor(BrightnessService.keyboardRed, v, BrightnessService.keyboardBlue)
                    }
                    VolumeSliderBar {
                        Layout.fillWidth: true
                        from: 0; to: 255
                        value: BrightnessService.keyboardBlue
                        fillColor: AppTheme.color12
                        handleColor: AppTheme.color12
                        onMoved: (v) => BrightnessService.setKeyboardColor(BrightnessService.keyboardRed, BrightnessService.keyboardGreen, v)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase
                    Repeater {
                        model: [AppTheme.accent, AppTheme.color9, AppTheme.color10, AppTheme.color11, AppTheme.color12, AppTheme.color13, AppTheme.color14, AppTheme.color7]
                        delegate: Rectangle {
                            required property color modelData
                            readonly property color swColor: modelData
                            width: 22
                            height: 22
                            radius: 11
                            border.width: 1
                            border.color: AppTheme.borderColor
                            color: swColor
                            scale: swHover.containsMouse ? 1.2 : 1.0
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            MouseArea {
                                id: swHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: BrightnessService.setKeyboardColor(swColor.r * 255, swColor.g * 255, swColor.b * 255)
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                // Velocidad de animación.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "Velocidad"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.textSecondary
                    }

                    VolumeSliderBar {
                        Layout.fillWidth: true
                        from: 0; to: 9
                        value: BrightnessService.keyboardSpeed
                        fillColor: AppTheme.accent
                        handleColor: AppTheme.accent
                        onMoved: (v) => BrightnessService.setKeyboardSpeed(v)
                    }
                }

                // Zonas (solo modo estático).
                RowLayout {
                    Layout.fillWidth: true
                    visible: BrightnessService.keyboardMode === 0
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "Zona"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.textSecondary
                    }

                    Repeater {
                        model: [1, 2, 3, 4]
                        delegate: Rectangle {
                            required property int modelData
                            readonly property int zoneIndex: modelData
                            readonly property bool active: BrightnessService.keyboardZone === zoneIndex
                            width: 30
                            height: 30
                            radius: 15
                            color: active ? AppTheme.accent : (zoneHover.containsMouse ? AppTheme.surface : "transparent")
                            border.width: active ? 0 : 1
                            border.color: active ? "transparent" : Qt.alpha(AppTheme.fg, 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: zoneIndex
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                font.weight: Font.Bold
                                color: active ? AppTheme.bg : AppTheme.fg
                            }
                            MouseArea {
                                id: zoneHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: BrightnessService.setKeyboardZone(zoneIndex)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            // ============ OTROS DISPOSITIVOS (escalable) ============
            ColumnLayout {
                Layout.fillWidth: true
                visible: BrightnessService.extraDevices.length > 0
                spacing: AppTheme.paddingBase

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: AppTheme.borderColor
                }

                Text {
                    Layout.fillWidth: true
                    text: "Otros dispositivos"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontBase
                    font.weight: Font.Bold
                    color: AppTheme.fg
                }

                Repeater {
                    model: BrightnessService.extraDevices
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: AppTheme.paddingSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: AppTheme.paddingBase
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                elide: Text.ElideRight
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                color: AppTheme.textSecondary
                            }
                            Text {
                                text: modelData.percent + "%"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                font.weight: Font.Bold
                                color: AppTheme.fg
                            }
                        }

                        VolumeSliderBar {
                            Layout.fillWidth: true
                            from: 0; to: 100
                            value: modelData.percent
                            fillColor: AppTheme.accent
                            handleColor: AppTheme.accent
                            onMoved: (v) => BrightnessService.setExtraDevice(modelData.name, v)
                        }
                    }
                }
            }
        }
    }

    // ===================== COMPONENTES REUTILIZABLES =====================
    // Botón de modo de efecto del teclado.
    Component {
        id: modeBtn
        Rectangle {
            required property var modelData
            readonly property int modeIndex: modelData[1]
            readonly property bool active: BrightnessService.keyboardMode === modeIndex
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: AppTheme.radius
            color: active ? AppTheme.accent : (modeHover.containsMouse ? AppTheme.surface : "transparent")
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
                anchors.centerIn: parent
                text: modelData[0]
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: active ? AppTheme.bg : AppTheme.fg
            }
            MouseArea {
                id: modeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BrightnessService.setKeyboardMode(modeIndex)
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
