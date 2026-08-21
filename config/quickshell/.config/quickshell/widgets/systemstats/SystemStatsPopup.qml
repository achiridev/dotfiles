// widgets/systemstats/SystemStatsPopup.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.globals
import qs.widgets.systemstats

PopupWindow {
    id: popup

    // Pill de temperatura del footer (termómetro + label + valor).
    component TempPill: Rectangle {
        id: pill
        property string label: ""
        property int temp: 0
        readonly property color c: SystemStatsService.statusColor(temp)

        implicitWidth: content.implicitWidth + 18
        implicitHeight: 24
        radius: height / 2
        color: Qt.alpha(c, 0.12)
        border.width: 1
        border.color: Qt.alpha(c, 0.3)

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: String.fromCodePoint(0xf2c8) //  termómetro
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                color: pill.c

                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Text {
                text: pill.label + " " + pill.temp + "°C"
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: pill.c

                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

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

    implicitWidth: 460
    implicitHeight: card.implicitHeight
    color: "transparent"

    Rectangle {
        id: card
        width: popup.implicitWidth
        implicitHeight: layout.implicitHeight + (AppTheme.paddingLarge + AppTheme.paddingBase) * 2
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
            anchors.margins: AppTheme.paddingLarge + AppTheme.paddingBase
            spacing: AppTheme.paddingLarge

            // ================= HEADER =================
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                Text {
                    text: String.fromCodePoint(0xf1119) // 󱄙 chip
                    font.family: AppTheme.fontMono
                    font.pixelSize: 24
                    color: AppTheme.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: "SYSTEM"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                        color: AppTheme.fg
                    }

                    Text {
                        Layout.fillWidth: true
                        text: SystemStatsService.gpuAvailable ? SystemStatsService.gpuName : "GPU no disponible"
                        elide: Text.ElideRight
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.textSecondary
                    }
                }
            }

            // ================= GAUGES =================
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                StatCard {
                    Layout.fillWidth: true
                    title: "CPU"
                    usage: SystemStatsService.cpuUsage
                    temp: SystemStatsService.cpuTemp
                    showTemp: SystemStatsService.hasCpuTemp
                    accentColor: SystemStatsService.cpuColor(SystemStatsService.cpuTemp)
                }

                StatCard {
                    Layout.fillWidth: true
                    title: "RAM"
                    usage: SystemStatsService.memUsage
                    accentColor: SystemStatsService.memColor(SystemStatsService.memPercent)
                }

                StatCard {
                    Layout.fillWidth: true
                    visible: SystemStatsService.gpuAvailable
                    title: "GPU"
                    usage: SystemStatsService.gpuUsage
                    temp: SystemStatsService.gpuTemp
                    showTemp: true
                    accentColor: SystemStatsService.gpuColor(SystemStatsService.gpuTemp)
                }
            }

            // ================= DIVISOR =================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            // ================= BARRAS =================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                UsageBar {
                    Layout.fillWidth: true
                    label: "MEMORY"
                    fraction: SystemStatsService.memPercent / 100
                    valueText: SystemStatsService.memUsedGb.toFixed(1) + " / " + SystemStatsService.memTotalGb.toFixed(1) + " GiB"
                    detailText: "Libre: " + SystemStatsService.memFreeGb.toFixed(1) + " GiB · Cache: " + SystemStatsService.memCachedGb.toFixed(1) + " GiB"
                    fillColor: SystemStatsService.memColor(SystemStatsService.memPercent)
                }

                UsageBar {
                    Layout.fillWidth: true
                    visible: SystemStatsService.gpuAvailable
                    label: "VRAM"
                    fraction: SystemStatsService.vramPercent / 100
                    valueText: SystemStatsService.vramUsedGb.toFixed(1) + " / " + SystemStatsService.vramTotalGb.toFixed(1) + " GiB"
                    fillColor: SystemStatsService.vramPercent > 90 ? AppTheme.critical : AppTheme.color12
                }
            }

            // ================= FOOTER (temps) =================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: AppTheme.paddingBase

                TempPill {
                    visible: SystemStatsService.hasLaptopTemp
                    label: "Laptop"
                    temp: SystemStatsService.laptopTemp
                }

                TempPill {
                    visible: SystemStatsService.hasNvmeTemp
                    label: "NVMe"
                    temp: SystemStatsService.nvmeTemp
                }
            }
        }
    }

    // Apertura: fade + escala + slide desde la barra (crece hacia abajo).
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "y"; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }

    // Cierre: se oculta la ventana recién cuando termina la animación.
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "scale"; to: 0.95; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "y"; to: 6; duration: 140; easing.type: Easing.InCubic }
        onFinished: popup.shown = false
    }
}
