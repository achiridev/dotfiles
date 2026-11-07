// widgets/clipboard/ClipboardEmptyState.qml
//
// Estado vacío / sin resultados. Solo presentación.
import QtQuick
import QtQuick.Layouts

import qs.globals
import qs.widgets.clipboard

Item {
    id: root

    property string query: ""
    property bool loading: false

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 460)
        spacing: AppTheme.paddingBase

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.loading ? String.fromCodePoint(0xf021)
                : root.query !== "" ? String.fromCodePoint(0xf002)
                : String.fromCodePoint(0xf0c5)
            font.family: AppTheme.fontMono
            font.pixelSize: 48
            color: ClipboardStyle.textTertiary
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.loading ? "Cargando historial…"
                : root.query !== "" ? "Sin resultados"
                : "El historial está vacío"
            wrapMode: Text.WordWrap
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontLarge
            font.weight: Font.Bold
            color: ClipboardStyle.textSecondary
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.loading
                ? "Leyendo el historial de cliphist."
                : root.query !== ""
                    ? "Ninguna entrada coincide con «" + root.query + "»."
                    : "Copia algo y aparecerá aquí automáticamente."
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontBase
            color: ClipboardStyle.textTertiary
        }
    }
}
