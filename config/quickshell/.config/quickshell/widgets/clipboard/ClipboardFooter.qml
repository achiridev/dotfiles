// widgets/clipboard/ClipboardFooter.qml
//
// Pie del gestor: atajos, error de la última operación y limpieza total con
// confirmación en dos pasos. Solo presentación + señal.
import QtQuick
import QtQuick.Layouts

import qs.globals
import qs.widgets.clipboard

Item {
    id: root

    property int count: 0
    property bool confirmClear: false
    property string error: ""

    signal clearRequested()

    implicitHeight: ClipboardStyle.footerHeight

    RowLayout {
        anchors.fill: parent
        spacing: AppTheme.paddingBase

        Text {
            Layout.fillWidth: true
            text: "↑↓ navegar · Enter copiar · Ctrl+Supr eliminar · Esc cerrar"
            elide: Text.ElideRight
            font.family: AppTheme.fontLayout
            font.pixelSize: ClipboardStyle.hintSize
            color: ClipboardStyle.textTertiary
        }

        Text {
            visible: root.error !== ""
            Layout.maximumWidth: 300
            text: root.error
            elide: Text.ElideRight
            font.family: AppTheme.fontLayout
            font.pixelSize: ClipboardStyle.hintSize
            color: ClipboardStyle.danger
        }

        Rectangle {
            id: clearButton

            readonly property bool canClear: root.count > 0

            Layout.preferredWidth: clearLabel.implicitWidth + AppTheme.paddingLarge * 2
            Layout.preferredHeight: 30
            radius: AppTheme.radiusSmall
            opacity: canClear ? 1.0 : 0.45
            color: !canClear ? ClipboardStyle.buttonBg
                 : root.confirmClear
                    ? (clearMa.containsMouse ? ClipboardStyle.buttonDangerHover : ClipboardStyle.buttonDangerBg)
                    : (clearMa.containsMouse ? ClipboardStyle.buttonHover : ClipboardStyle.buttonBg)
            border.width: 1
            border.color: root.confirmClear
                ? Qt.alpha(ClipboardStyle.danger, 0.55)
                : Qt.alpha(AppTheme.fg, 0.08)

            Behavior on color { ColorAnimation { duration: ClipboardStyle.animFast } }

            Text {
                id: clearLabel
                anchors.centerIn: parent
                text: !root.confirmClear ? "Limpiar historial" : "¿Confirmar limpieza?"
                font.family: AppTheme.fontLayout
                font.pixelSize: ClipboardStyle.metaSize
                font.weight: Font.Bold
                color: root.confirmClear ? ClipboardStyle.danger : ClipboardStyle.textSecondary
            }

            MouseArea {
                id: clearMa
                anchors.fill: parent
                enabled: clearButton.canClear
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearRequested()
            }
        }
    }
}
