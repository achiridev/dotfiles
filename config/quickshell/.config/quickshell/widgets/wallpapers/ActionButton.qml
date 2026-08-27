// widgets/wallpapers/ActionButton.qml
// Botón compacto de acción (glifo + etiqueta) usado en la barra de control.
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.globals

Rectangle {
    id: root

    property string label: ""
    property string glyph: ""
    property bool enabled: true

    signal clicked

    implicitWidth: contentRow.implicitWidth + AppTheme.paddingLarge * 2
    implicitHeight: 30
    radius: AppTheme.radius

    color: {
        if (!root.enabled) return Qt.alpha(AppTheme.fg, 0.04)
        return hover.containsMouse ? AppTheme.bgModuleHover : Qt.alpha(AppTheme.fg, 0.06)
    }
    Behavior on color {
        ColorAnimation { duration: AppTheme.wpAnimFast }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: AppTheme.paddingSmall

        Text {
            text: root.glyph + (root.label ? " " + root.label : "")
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontSmall
            font.weight: Font.Bold
            color: root.enabled ? AppTheme.fg : AppTheme.textTertiary
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}