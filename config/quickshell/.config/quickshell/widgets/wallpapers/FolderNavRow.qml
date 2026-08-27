// widgets/wallpapers/FolderNavRow.qml
// Entrada de navegación lateral (carpeta/filtro) con contador y borrado opcional.
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.globals
import qs.services

Rectangle {
    id: root

    required property string label
    required property int count
    required property string folder
    property bool deletable: false

    signal clickedFolder
    signal deleteRequested

    readonly property bool active: WallpaperService.activeFolder === folder
    readonly property bool hovered: mouse.containsMouse

    Layout.fillWidth: true
    Layout.preferredHeight: 32
    radius: AppTheme.radiusSmall
    color: {
        if (active) return AppTheme.surface
        if (hovered) return Qt.alpha(AppTheme.fg, 0.06)
        return "transparent"
    }
    Behavior on color {
        ColorAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: 3
        radius: 1.5
        visible: root.active
        color: AppTheme.accent
    }

    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: 12
            rightMargin: 20
        }
        spacing: AppTheme.paddingSmall

        Text {
            Layout.fillWidth: true
            id: folderLabel
            text: root.label
            elide: Text.ElideRight
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontSmall
            font.weight: root.active ? Font.Bold : Font.Normal
            color: root.active ? AppTheme.fg : AppTheme.textSecondary
        }

        Text {
            text: root.count
            Layout.alignment: Qt.AlignRight
            Layout.minimumWidth: 16
            horizontalAlignment: Text.AlignRight
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontTiny
            font.weight: Font.Bold
            color: root.active ? AppTheme.accent : AppTheme.textTertiary
        }
    }

    // Borrar en overlay: no reflow el label al aparecer en hover.
    Rectangle {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 5
        }
        visible: root.deletable && root.hovered
        width: 16
        height: 16
        radius: 8
        color: delHover.containsMouse ? AppTheme.critical : Qt.alpha(AppTheme.critical, 0.45)
        Behavior on color {
            ColorAnimation { duration: AppTheme.wpAnimFast }
        }
        MouseArea {
            id: delHover
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.deleteRequested()
        }
        Text {
            anchors.centerIn: parent
            text: "✕"
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontTiny
            font.weight: Font.Bold
            color: AppTheme.bg
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clickedFolder()
    }
}