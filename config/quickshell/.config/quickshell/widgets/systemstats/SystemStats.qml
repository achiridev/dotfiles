// widgets/systemstats/SystemStats.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.globals

// Módulo compacto de la barra: uso de CPU y RAM. Hover abre el panel SYSTEM.
// El ancho es FIJO (calculado con el peor caso "100%") y cada texto de %
// tiene celda propia centrada: pasar de 9% a 10% no mueve ni redimensiona nada.
Item {
    id: root

    readonly property int spacing: AppTheme.paddingSmall
    readonly property int sepWidth: 1

    // Métricas para el ancho fijo: peor caso "100%" en ambas fuentes.
    TextMetrics {
        id: pctMetrics
        font.family: AppTheme.fontLayout
        font.pixelSize: AppTheme.fontBase
        font.weight: Font.Bold
        text: "100%"
    }

    TextMetrics {
        id: cpuIconMetrics
        font.family: AppTheme.fontMono
        font.pixelSize: AppTheme.fontBase
        text: String.fromCodePoint(0xf2db) //  microchip
    }

    TextMetrics {
        id: ramIconMetrics
        font.family: AppTheme.fontMono
        font.pixelSize: AppTheme.fontBase
        text: String.fromCodePoint(0xf035b) // 󰍛 memory
    }

    readonly property int fixedWidth: AppTheme.paddingBase * 2
        + cpuIconMetrics.width + pctMetrics.width
        + sepWidth
        + ramIconMetrics.width + pctMetrics.width
        + root.spacing * 4

    implicitWidth: root.fixedWidth
    implicitHeight: AppTheme.heightBar

    property bool popupOpen: false

    // HoverHandler reporta hover sin robar eventos de los MouseArea hijos
    // (a diferencia de MouseArea.containsMouse, que solo es true en el topmost).
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool shouldOpen: hovered || popup.hovered

    onShouldOpenChanged: {
        if (root.shouldOpen) {
            closeTimer.stop()
            root.popupOpen = true
        } else {
            // Retardo corto para no cerrar al cruzar bordes entre widget y popup.
            closeTimer.restart()
        }
    }

    onPopupOpenChanged: {
        // Cadencia rápida + polling de GPU solo mientras el popup está abierto.
        SystemStatsService.detailMode = root.popupOpen
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
            spacing: root.spacing

            Text {
                text: String.fromCodePoint(0xf2db) //  microchip
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                color: SystemStatsService.cpuColor(SystemStatsService.cpuTemp)

                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Text {
                Layout.preferredWidth: pctMetrics.width
                horizontalAlignment: Text.AlignHCenter
                text: SystemStatsService.cpuUsage + "%"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.fg
            }

            Rectangle {
                Layout.preferredWidth: root.sepWidth
                Layout.preferredHeight: 14
                color: AppTheme.borderColor
            }

            Text {
                text: String.fromCodePoint(0xf035b) // 󰍛 memory
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                color: SystemStatsService.memColor(SystemStatsService.memPercent)

                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Text {
                Layout.preferredWidth: pctMetrics.width
                horizontalAlignment: Text.AlignHCenter
                text: SystemStatsService.memUsage + "%"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.fg
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.NoButton
    }

    SystemStatsPopup {
        id: popup
        anchorItem: root
        requestOpen: root.popupOpen
    }
}
