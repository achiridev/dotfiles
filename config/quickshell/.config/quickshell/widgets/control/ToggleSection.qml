// widgets/control/ToggleSection.qml
// Sección "Componentes" del Panel de Control. Permite activar/desactivar los
// componentes de Quickshell (Bar, Overview, Wallpapers, Launcher, Activate,
// Visualizer). Cada toggle escribe ControlState.<x>Enabled, que alimenta los
// Loaders de shell.qml.
import QtQuick
import QtQuick.Layouts
import qs.globals

Item {
    id: root

    // Altura natural de la sección (para que el panel se ajuste).
    readonly property int sectionHeight: 320

    // Fila con switch on/off reutilizable en toda la sección.
    component ToggleRow: Rectangle {
        id: row
        property string label: ""
        property string icon: ""
        property bool checked: false
        property var onToggled: null

        readonly property color activeColor: checked ? AppTheme.accent : AppTheme.color8

        Layout.fillWidth: true
        implicitHeight: rowRow.implicitHeight + AppTheme.paddingBase * 2
        radius: AppTheme.radiusSmall
        color: checked ? Qt.alpha(AppTheme.accent, 0.14)
             : ma.containsMouse ? AppTheme.surface
             : Qt.alpha(AppTheme.fg, 0.03)
        border.width: 1
        border.color: checked ? Qt.alpha(AppTheme.accent, 0.5) : Qt.alpha(AppTheme.fg, 0.08)

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: rowRow
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: AppTheme.paddingBase

            Text {
                text: row.icon
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontLarge
                color: row.activeColor

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                Layout.fillWidth: true
                text: row.label
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: checked ? AppTheme.fg : AppTheme.textSecondary

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Switch on/off
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 24
                radius: height / 2
                color: checked ? Qt.alpha(row.activeColor, 0.85) : Qt.alpha(AppTheme.fg, 0.12)
                border.width: 1
                border.color: checked ? row.activeColor : Qt.alpha(AppTheme.fg, 0.2)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: checked ? parent.width - height - 2 : 2
                    width: 20
                    height: 20
                    radius: height / 2
                    color: "#ffffff"

                    Behavior on anchors.leftMargin { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (row.onToggled) row.onToggled() }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: AppTheme.paddingSmall

        ToggleRow {
            label: "Bar"
            icon: String.fromCodePoint(0xf0c9) // hamburguesa/menú
            checked: ControlState.barEnabled
            onToggled: () => { ControlState.barEnabled = !ControlState.barEnabled }
        }

        ToggleRow {
            label: "Overview"
            icon: String.fromCodePoint(0xf009) // cuadrícula
            checked: ControlState.overviewEnabled
            onToggled: () => { ControlState.overviewEnabled = !ControlState.overviewEnabled }
        }

        ToggleRow {
            label: "Wallpapers"
            icon: String.fromCodePoint(0xf03e) // imagen
            checked: ControlState.wallpapersEnabled
            onToggled: () => { ControlState.wallpapersEnabled = !ControlState.wallpapersEnabled }
        }

        ToggleRow {
            label: "Launcher"
            icon: String.fromCodePoint(0xf013) // engranaje
            checked: ControlState.launcherEnabled
            onToggled: () => { ControlState.launcherEnabled = !ControlState.launcherEnabled }
        }

        ToggleRow {
            label: "Activate"
            icon: String.fromCodePoint(0xf305) // marcar/activar
            checked: ControlState.activateEnabled
            onToggled: () => { ControlState.activateEnabled = !ControlState.activateEnabled }
        }

        ToggleRow {
            label: "Visualizer"
            icon: String.fromCodePoint(0xf145) // ondas/audio
            checked: ControlState.visualizerEnabled
            onToggled: () => { ControlState.visualizerEnabled = !ControlState.visualizerEnabled }
        }

        // Espaciador para mantener el contenido arriba.
        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: String.fromCodePoint(0xf0c9)
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                color: AppTheme.textTertiary
            }

            Text {
                Layout.fillWidth: true
                text: "Activación instantánea · libera RAM"
                elide: Text.ElideRight
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                color: AppTheme.textTertiary
            }
        }
    }
}
