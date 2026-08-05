import QtQuick
import QtQuick.Layouts
import qs.services
import qs.globals

// Fila reutilizable para un dispositivo (sink/source): glifo por tipo,
// nombre + descripción, badge de activo y click para seleccionar como default.
Rectangle {
    id: root

    required property var node
    required property bool isDefault

    signal selectRequested()

    Layout.fillWidth: true
    implicitHeight: 42
    radius: AppTheme.radius
    border.width: 1
    border.color: isDefault ? "transparent" : AppTheme.borderColor
    color: {
        if (isDefault) return Qt.alpha(AppTheme.accent, 0.9)
        return mouse.containsMouse ? AppTheme.surface : "transparent"
    }

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: AppTheme.paddingLarge
        anchors.rightMargin: AppTheme.paddingLarge
        spacing: AppTheme.paddingBase

        Text {
            text: AudioService.nodeGlyph(root.node)
            font.family: AppTheme.fontMono
            font.pixelSize: 20
            color: isDefault ? AppTheme.bg : AppTheme.accent
            Layout.preferredWidth: 32
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
                font.weight: isDefault ? Font.Bold : Font.Medium
                color: isDefault ? AppTheme.bg : AppTheme.fg
            }
            Text {
                Layout.fillWidth: true
                text: AudioService.deviceSubtitle(root.node)
                elide: Text.ElideRight
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                color: isDefault ? Qt.alpha(AppTheme.bg, 0.7) : AppTheme.textSecondary
                visible: text.length > 0
            }
        }

        Rectangle {
            visible: isDefault
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            radius: 11
            color: AppTheme.bg

            Text {
                anchors.centerIn: parent
                text: "✓"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: AppTheme.accent
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selectRequested()
    }
}
