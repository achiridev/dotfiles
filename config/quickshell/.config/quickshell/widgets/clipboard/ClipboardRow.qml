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

    property var modelData
    property bool selected: false

    readonly property var entry: modelData ? modelData : null
    readonly property bool isHovered: rowMa.containsMouse

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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: AppTheme.paddingBase
        anchors.rightMargin: AppTheme.paddingBase
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

        Rectangle {
            visible: root.selected || root.isHovered
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
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
}
