// widgets/clipboard/ClipboardList.qml
//
// Lista virtualizada del historial. Solo crea los delegates visibles
// (`reuseItems` + cacheBuffer acotado) y mantiene la fila seleccionada a la
// vista. Componente STATELESS: no ejecuta operaciones del portapapeles.
import QtQuick
import QtQuick.Controls

import qs.services
import qs.widgets.clipboard

Item {
    id: root

    property int selectedIndex: 0

    signal activated(string id)
    signal deleteRequested(string id)
    signal hovered(string id)

    function scrollTo(index) {
        if (index < 0 || index >= list.count)
            return
        list.positionViewAtIndex(index, ListView.Contain)
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: ClipboardStyle.rowSpacing
        model: ClipboardService.filtered
        reuseItems: true
        cacheBuffer: ClipboardStyle.listCacheBuffer
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        delegate: ClipboardRow {
            required property int index
            selected: index === root.selectedIndex
            onActivated: id => root.activated(id)
            onDeleteRequested: id => root.deleteRequested(id)
            onHovered: id => root.hovered(id)
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 6
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: ClipboardStyle.scrollbar
            }
        }
    }

    onSelectedIndexChanged: Qt.callLater(root.scrollTo, root.selectedIndex)

    Connections {
        target: ClipboardService
        function onFilteredChanged() {
            Qt.callLater(root.scrollTo, root.selectedIndex)
        }
    }
}
