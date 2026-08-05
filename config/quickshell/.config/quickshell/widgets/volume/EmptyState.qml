import QtQuick
import QtQuick.Layouts
import qs.globals

RowLayout {
    property string text

    spacing: AppTheme.paddingSmall

    Text {
        text: "󰂻"
        font.family: AppTheme.fontMono
        font.pixelSize: AppTheme.fontSmall
        color: AppTheme.textTertiary
    }
    Text {
        text: parent.text
        font.family: AppTheme.fontLayout
        font.pixelSize: AppTheme.fontSmall
        color: AppTheme.textTertiary
    }
}
