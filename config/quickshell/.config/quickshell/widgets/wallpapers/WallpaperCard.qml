// widgets/wallpapers/WallpaperCard.qml
// Tarjeta de wallpaper: preview (thumb en cache, con placeholder para items
// sin archivo), etiqueta con nombre + tipo, anillo del wallpaper actual y
// overlay de "Aplicando…". Click = aplicar; click derecho = asignar a carpeta.
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.globals
import qs.services

Item {
    id: root

    required property var modelData
    property bool selected: false

    signal clicked
    signal contextRequested

    readonly property string wpId: modelData ? String(modelData.id) : ""
    readonly property string wpName: modelData ? modelData.name : ""
    readonly property bool isCurrent: wpId !== "" && WallpaperService.currentId === wpId
    readonly property bool isApplying: wpId !== "" && WallpaperService.applyingId === wpId
    readonly property bool hovered: hoverHandler.hovered

    width: AppTheme.wpTileW
    height: AppTheme.wpTileH

    scale: root.hovered ? 1.03 : 1.0
    Behavior on scale {
        NumberAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: AppTheme.radius
        color: root.hovered ? AppTheme.bgModuleHover : AppTheme.bgModule
        border.color: isApplying ? AppTheme.warning
                    : isCurrent || root.selected ? AppTheme.wpCurrentRing
                                                 : AppTheme.borderColor
        border.width: (isApplying || isCurrent || root.selected) ? 2 : 1

        Behavior on color {
            ColorAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
        }

        // ---- Imagen ----
        LazyImage {
            id: previewImage
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: AppTheme.paddingSmall
                leftMargin: AppTheme.paddingSmall
                rightMargin: AppTheme.paddingSmall
            }
            height: root.height - AppTheme.paddingSmall * 2 - 24
            source: modelData ? modelData.thumb : ""
            maxSourceWidth: AppTheme.wpThumbW
        }

        // ---- Etiqueta inferior ----
        Rectangle {
            id: labelRow
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: AppTheme.paddingSmall
                rightMargin: AppTheme.paddingSmall
                bottomMargin: AppTheme.paddingSmall
            }
            height: 24
            radius: AppTheme.radiusSmall
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                spacing: AppTheme.paddingSmall

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.wpName
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    font.weight: Font.Bold
                    color: AppTheme.fg
                }

                Text {
                    id: typeText
                    Layout.alignment: Qt.AlignRight
                    Layout.minimumWidth: 30
                    Layout.preferredWidth: implicitWidth
                    horizontalAlignment: Text.AlignRight
                    text: root.isCurrent ? "Actual" : root.typeLabel
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontTiny
                    font.weight: Font.Bold
                    color: root.isCurrent ? AppTheme.accent : AppTheme.textSecondary
                }
            }
        }

        // ---- Badge tipo (superior derecha) ----
        Rectangle {
            id: typeBadge
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 6
                rightMargin: 6
            }
            readonly property bool show: !root.isCurrent
            visible: show && !root.isApplying
            height: 18
            width: typeBadgeText.implicitWidth + AppTheme.paddingBase * 2
            radius: height / 2
            color: Qt.alpha(AppTheme.bg, 0.55)

            Text {
                id: typeBadgeText
                anchors.centerIn: parent
                text: root.typeLabel
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                font.weight: Font.Bold
                color: AppTheme.fg
            }
        }

        // ---- Anillo "Actual" (superior derecha) ----
        Rectangle {
            visible: root.isCurrent && !root.isApplying
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 6
                rightMargin: 6
            }
            width: 22
            height: 22
            radius: 11
            color: AppTheme.wpCurrentRing

            Text {
                anchors.centerIn: parent
                text: "✓"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.bg
            }
        }

        // ---- Overlay "Aplicando…" ----
        Rectangle {
            visible: root.isApplying
            anchors.fill: parent
            radius: AppTheme.radius
            color: Qt.alpha(AppTheme.bg, 0.6)

            Text {
                anchors.centerIn: parent
                text: "Aplicando…"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.warning
            }
        }
    }

    readonly property string typeLabel: {
        if (!modelData) return ""
        if (modelData.type === "scene") return "Escena"
        if (modelData.type === "video") return "Video"
        if (modelData.type === "web") return "Web"
        return modelData.type
    }

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.clicked()
            else
                root.contextRequested()
        }
    }
}