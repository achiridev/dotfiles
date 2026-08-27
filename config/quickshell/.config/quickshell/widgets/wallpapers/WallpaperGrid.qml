// widgets/wallpapers/WallpaperGrid.qml
// Grid de tarjetas con recycling (cacheBuffer 0), carga perezosa y navegación
// por teclado (flechas + Enter). El modelo es `WallpaperService.visibleItems`.
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.globals
import qs.services

GridView {
    id: root

    signal askMenu(var item, Item anchor)

    model: WallpaperService.visibleItems
    cellWidth: AppTheme.wpCellW
    cellHeight: AppTheme.wpCellH
    cacheBuffer: 0
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 3000
    keyNavigationWraps: true

    function applyCurrent() {
        if (root.currentIndex >= 0 && root.currentIndex < count) {
            const item = root.model[root.currentIndex]
            if (item && item.id)
                WallpaperService.apply(item.id)
        }
    }

    delegate: Component {
        Item {
            id: wrap
            required property var modelData
            required property int index
            width: GridView.view.cellWidth
            height: GridView.view.cellHeight

            WallpaperCard {
                id: card
                anchors.centerIn: parent
                modelData: wrap.modelData
                selected: root.currentIndex === index

                onClicked: WallpaperService.apply(wrap.modelData.id)
                onContextRequested: root.askMenu(wrap.modelData, card)
            }
        }
    }

    // Scrollbar minimalista (GridView viene de Flickable).
    Rectangle {
        id: scrollTrack
        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
        }
        width: 5
        radius: 2.5
        visible: root.contentHeight > root.height
        color: Qt.alpha(AppTheme.fg, 0.1)

        Rectangle {
            width: parent.width
            radius: parent.radius
            color: Qt.alpha(AppTheme.fg, 0.35)

            readonly property real trackHeight: scrollTrack.height
            readonly property real scrollable: Math.max(1, root.contentHeight - root.height)
            y: (root.contentY / scrollable) * (trackHeight - height)
            height: Math.max(24, trackHeight * trackHeight / root.contentHeight)
        }
    }
}