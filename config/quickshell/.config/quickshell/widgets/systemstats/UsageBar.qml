// widgets/systemstats/UsageBar.qml
import QtQuick
import QtQuick.Layouts
import qs.globals

// Barra de uso genérica (MEMORY / VRAM): label + track con fill animado +
// valor a la derecha + línea de detalle opcional.
Rectangle {
    id: root

    property string label: ""
    property real fraction: 0 // 0..1
    property string valueText: ""
    property string detailText: ""
    property color fillColor: AppTheme.accent

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    radius: AppTheme.radiusSmall
    color: "transparent"

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: AppTheme.paddingSmall

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.label
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: AppTheme.textSecondary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.valueText
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontTiny
                color: AppTheme.textSecondary
            }
        }

        Rectangle {
            id: track
            Layout.fillWidth: true
            implicitHeight: 10
            radius: height / 2
            color: Qt.alpha(AppTheme.fg, 0.10)

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    margins: 2
                }
                radius: height / 2
                width: (track.width - 4) * Math.max(0, Math.min(1, root.fraction))

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.fillColor }
                    GradientStop { position: 1; color: Qt.lighter(root.fillColor, 1.3) }
                }

                Behavior on width {
                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            visible: root.detailText !== ""
            text: root.detailText
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontTiny
            color: AppTheme.textTertiary
        }
    }
}
