import QtQuick
import QtQuick.Layouts
import qs.globals

RowLayout {
    property string text
    property int topMargin: 0

    spacing: AppTheme.paddingSmall
    Layout.topMargin: topMargin

    Rectangle {
        Layout.preferredWidth: 6
        Layout.preferredHeight: 6
        radius: 3
        color: AppTheme.accent
    }
    Text {
        text: parent.text
        font.family: AppTheme.fontLayout
        font.pixelSize: AppTheme.fontSmall
        font.weight: Font.Bold
        color: AppTheme.textSecondary
    }
}
