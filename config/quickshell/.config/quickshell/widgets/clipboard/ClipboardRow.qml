// widgets/clipboard/ClipboardRow.qml
//
// Fila de una entrada del historial. Componente STATELESS: recibe `entry` y
// `selected`, y emite señales. No conoce ClipboardService ni ejecuta acciones.
import QtQuick
import QtQuick.Layouts

import qs.globals
import qs.widgets.clipboard

Rectangle {
    id: root

    property var entry: null
    property bool selected: false

    readonly property int deleteButtonSize: 26
    // El botón de borrar está por encima del MouseArea de la fila; si solo se
    // mirara rowMa.containsMouse, el botón desaparecería al intentar pulsarlo.
    readonly property bool isHovered: rowMa.containsMouse || deleteMa.containsMouse

    readonly property color kindColor: !entry ? ClipboardStyle.textKindColor
        : entry.kind === "image" ? ClipboardStyle.imageKindColor
        : entry.kind === "binary" ? ClipboardStyle.binaryKindColor
        : ClipboardStyle.textKindColor

    readonly property string kindIcon: !entry ? ""
        : entry.kind === "image" ? String.fromCodePoint(0xf03e)
        : entry.kind === "binary" ? String.fromCodePoint(0xf0c5)
        : String.fromCodePoint(0xf0f6)

    signal activated(string id)
    signal deleteRequested(string id)
    signal hovered(string id)

    implicitWidth: ListView.view ? ListView.view.width : 300
    implicitHeight: ClipboardStyle.rowHeight
    radius: ClipboardStyle.rowRadius
    color: selected ? ClipboardStyle.rowSelected
         : isHovered ? ClipboardStyle.rowHover
         : ClipboardStyle.rowColor
    border.width: selected ? 1 : 0
    border.color: ClipboardStyle.rowSelectedBorder

    Behavior on color { ColorAnimation { duration: ClipboardStyle.animFast } }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: AppTheme.paddingBase
        // Reserva el hueco del botón de borrar (margen + botón + margen).
        anchors.rightMargin: AppTheme.paddingBase * 2 + root.deleteButtonSize
        spacing: AppTheme.paddingBase

        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: AppTheme.radiusSmall
            color: Qt.alpha(root.kindColor, 0.13)
            border.width: 1
            border.color: Qt.alpha(root.kindColor, 0.28)

            Text {
                anchors.centerIn: parent
                text: root.kindIcon
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontLarge
                color: root.kindColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.entry ? root.entry.summary : ""
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                color: ClipboardStyle.textPrimary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                Text {
                    text: root.entry ? root.entry.kindLabel : ""
                    font.family: AppTheme.fontLayout
                    font.pixelSize: ClipboardStyle.metaSize
                    font.weight: Font.Bold
                    color: root.kindColor
                }

                Text {
                    Layout.fillWidth: true
                    text: root.entry ? root.entry.meta : ""
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: AppTheme.fontMono
                    font.pixelSize: ClipboardStyle.metaSize
                    color: ClipboardStyle.textTertiary
                }
            }
        }
    }

    // Va por encima del contenido para recibir hover y clic en toda la fila.
    MouseArea {
        id: rowMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (root.entry)
                root.hovered(root.entry.id)
        }
        onClicked: {
            if (root.entry)
                root.activated(root.entry.id)
        }
    }

    // Por encima de rowMa: recibe su propio clic y no dispara la copia.
    Rectangle {
        id: deleteButton
        width: root.deleteButtonSize
        height: root.deleteButtonSize
        anchors.right: parent.right
        anchors.rightMargin: AppTheme.paddingBase
        anchors.verticalCenter: parent.verticalCenter
        visible: root.selected || root.isHovered
        radius: AppTheme.radiusSmall
        color: deleteMa.containsMouse ? ClipboardStyle.buttonDangerBg : "transparent"

        Text {
            anchors.centerIn: parent
            text: "✕"
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontSmall
            font.weight: Font.Bold
            color: deleteMa.containsMouse ? ClipboardStyle.danger : ClipboardStyle.textTertiary
        }

        MouseArea {
            id: deleteMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.entry)
                    root.deleteRequested(root.entry.id)
            }
        }
    }
}
