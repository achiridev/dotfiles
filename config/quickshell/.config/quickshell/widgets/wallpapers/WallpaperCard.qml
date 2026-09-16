// widgets/wallpapers/WallpaperCard.qml
// Previsualización de wallpaper al aire: solo contorno (borde) e imagen, sin
// relleno de fondo ni etiquetas. Anillo del wallpaper actual, overlay de
// "Aplicando…" y hover con borde de acento. Click = aplicar; click derecho =
// asignar a carpeta.
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
        color: "transparent"
        border.color: isApplying ? AppTheme.warning
                    : isCurrent || root.selected ? AppTheme.wpCurrentRing
                    : root.hovered ? Qt.alpha(AppTheme.accent, 0.55)
                                   : AppTheme.borderColor
        border.width: (isApplying || isCurrent || root.selected) ? 2 : 1

        Behavior on border.color {
            ColorAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
        }

        // ---- Imagen ----
        LazyImage {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: AppTheme.paddingSmall
                leftMargin: AppTheme.paddingSmall
                rightMargin: AppTheme.paddingSmall
                bottomMargin: AppTheme.paddingSmall
            }
            source: modelData ? modelData.thumb : ""
            maxSourceWidth: AppTheme.wpThumbW
        }

        // ---- Anillo "Actual" (superior derecha) ----
        Rectangle {
            visible: root.isCurrent && !root.isApplying
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 8
                rightMargin: 8
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