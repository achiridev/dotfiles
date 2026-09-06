// widgets/control/EnergySection.qml
// Sección "Energía" del Panel de Control. Reutiliza BatteryService (misma
// lógica que el antiguo BatteryPanel): los 4 modos del script
// ~/.local/bin/battery-mode y las pills de estado del sistema.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.globals

Item {
    id: root

    // Altura natural de la sección (para que el panel se ajuste).
    readonly property int sectionHeight: 320

    component ModeButton: Rectangle {
        id: btn
        property string mode: ""
        property string icon: ""
        property string title: ""
        property string desc: ""

        readonly property bool isActive: BatteryService.activeMode === mode

        Layout.fillWidth: true
        implicitHeight: btnRow.implicitHeight + AppTheme.paddingLarge * 2
        radius: AppTheme.radiusSmall
        color: isActive ? Qt.alpha(AppTheme.accent, 0.16)
             : mouse.containsMouse ? AppTheme.surface
             : Qt.alpha(AppTheme.fg, 0.03)
        border.width: 1
        border.color: isActive ? Qt.alpha(AppTheme.accent, 0.55) : Qt.alpha(AppTheme.fg, 0.08)

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: btnRow
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: AppTheme.paddingBase

            Text {
                text: btn.icon
                font.family: AppTheme.fontMono
                font.pixelSize: 22
                color: btn.isActive ? AppTheme.accent : AppTheme.textSecondary
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: btn.title
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontBase
                    font.weight: Font.Bold
                    color: btn.isActive ? AppTheme.accent : AppTheme.fg
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    text: btn.desc
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textTertiary
                }
            }

            Text {
                visible: btn.isActive
                text: String.fromCodePoint(0xf00c) // ✓ check
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.accent
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: BatteryService.applyMode(btn.mode)
        }
    }

    component StatusPill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property string value: ""
        property color c: AppTheme.accent

        implicitWidth: pillRow.implicitWidth + AppTheme.paddingBase * 2 + 4
        implicitHeight: pillRow.implicitHeight + AppTheme.paddingSmall * 2
        radius: height / 2
        color: Qt.alpha(c, 0.10)
        border.width: 1
        border.color: Qt.alpha(c, 0.28)

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

        RowLayout {
            id: pillRow
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: 6

            Text {
                text: pill.icon
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                color: pill.c
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Text {
                text: pill.label
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                color: AppTheme.textSecondary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: pill.value
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: pill.c
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: root.width
            spacing: AppTheme.paddingBase

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "MODO DE ENERGÍA"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: AppTheme.textSecondary
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "requiere sudo"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textTertiary
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: AppTheme.paddingSmall
                rowSpacing: AppTheme.paddingSmall

                ModeButton { mode: "off"; icon: String.fromCodePoint(0xf0082); title: "Normal"; desc: "GPU híbrida · CPU auto" }
                ModeButton { mode: "low"; icon: String.fromCodePoint(0xf007b); title: "Ahorro"; desc: "powersave · turbo off" }
                ModeButton { mode: "high"; icon: String.fromCodePoint(0xf186); title: "Ahorro máx."; desc: "solo iGPU · BT off · dpms" }
                ModeButton { mode: "gaming"; icon: String.fromCodePoint(0xf0e7); title: "Gaming"; desc: "GPU dedicada · performance" }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            Text {
                text: "ESTADO DEL SISTEMA"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: AppTheme.textSecondary
            }

            Flow {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                StatusPill {
                    icon: String.fromCodePoint(0xf1119) // chip
                    label: "GPU"
                    value: BatteryService.gpuMode || "?"
                    c: BatteryService.gpuMode === "integrated" ? AppTheme.success
                     : BatteryService.gpuMode === "nvidia" ? AppTheme.warning
                     : BatteryService.gpuMode === "" ? AppTheme.color8
                     : AppTheme.accent
                }

                StatusPill {
                    icon: String.fromCodePoint(0xf2db) // microchip
                    label: "CPU"
                    value: (BatteryService.governor || "?") + (BatteryService.turboEnabled ? " · boost ON" : " · boost OFF")
                    c: BatteryService.governor === "performance" ? AppTheme.warning
                     : BatteryService.governor === "powersave" ? AppTheme.success
                     : AppTheme.accent
                }

                StatusPill {
                    icon: String.fromCodePoint(0xf013) // engranaje
                    label: "TLP"
                    value: BatteryService.tlpActive ? "activo" : "inactivo"
                    c: BatteryService.tlpActive ? AppTheme.success : AppTheme.critical
                }

                StatusPill {
                    icon: String.fromCodePoint(0xf013)
                    label: "CPUFREQ"
                    value: BatteryService.cpufreqActive ? "activo" : "inactivo"
                    c: BatteryService.cpufreqActive ? AppTheme.success : AppTheme.critical
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}