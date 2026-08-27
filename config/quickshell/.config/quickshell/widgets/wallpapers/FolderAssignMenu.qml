// widgets/wallpapers/FolderAssignMenu.qml
// Menú contextual (in-app) para asignar un wallpaper a carpetas. Cubre todo el
// app: clics fuera cierran; lista las carpetas con check de pertenencia y un
// campo de creación rápida que asigna el item a la carpeta nueva al crear.
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.globals
import qs.services

Item {
    id: root

    property var item: null
    readonly property bool open: item !== null

    signal closeRequested

    visible: open
    enabled: open
    z: 100

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.closeRequested()
    }

    Rectangle {
        id: box
        width: 236
        height: contentLayout.implicitHeight + AppTheme.paddingLarge * 2
        radius: AppTheme.radiusLarge
        color: AppTheme.bgPopup
        border.width: 1
        border.color: AppTheme.borderColor
        z: 1

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: "Asignar a carpeta"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: AppTheme.fg
            }

            Text {
                Layout.fillWidth: true
                text: root.item ? root.item.name : ""
                elide: Text.ElideRight
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                color: AppTheme.textSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: AppTheme.paddingSmall
                Layout.bottomMargin: AppTheme.paddingSmall
                color: AppTheme.borderColor
            }

            Repeater {
                model: WallpaperService.folders

                delegate: Rectangle {
                    required property var modelData
                    readonly property string folderName: modelData ? modelData.name : ""
                    readonly property bool inFolder: root.item ? WallpaperService.itemInFolder(root.item.id, folderName) : false

                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    radius: AppTheme.radiusSmall
                    color: rowHover.containsMouse ? AppTheme.surface : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: AppTheme.wpAnimFast }
                    }

                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: AppTheme.paddingSmall

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 4
                            border.width: 1
                            border.color: inFolder ? AppTheme.accent : AppTheme.borderColor
                            color: inFolder ? AppTheme.accent : "transparent"
                            Behavior on color {
                                ColorAnimation { duration: AppTheme.wpAnimFast }
                            }
                            Text {
                                visible: inFolder
                                anchors.centerIn: parent
                                text: "✓"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: AppTheme.bg
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: folderName
                            elide: Text.ElideRight
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.fg
                        }

                        Text {
                            text: WallpaperService.folderCount(folderName)
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontTiny
                            color: AppTheme.textTertiary
                        }
                    }

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.item)
                                WallpaperService.toggleItemInFolder(root.item.id, folderName)
                        }
                    }
                }
            }

            // ---- Crea carpeta y asigna el item al instante ----
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: AppTheme.paddingSmall
                spacing: 4

                TextInput {
                    id: quickInput
                    Layout.fillWidth: true
                    clip: true
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.fg
                    selectByMouse: true
                    onAccepted: root.quickCreate()

                    Text {
                        anchors.fill: parent
                        visible: quickInput.length === 0
                        verticalAlignment: Text.AlignVCenter
                        text: "Nueva carpeta…"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.textTertiary
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: quickHover.containsMouse ? AppTheme.bgModuleHover : Qt.alpha(AppTheme.fg, 0.08)
                    Behavior on color {
                        ColorAnimation { duration: AppTheme.wpAnimFast }
                    }
                    MouseArea {
                        id: quickHover
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.quickCreate()
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "＋"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.fg
                    }
                }
            }
        }
    }

    function quickCreate() {
        const name = quickInput.text.trim()
        if (!name || !root.item)
            return
        WallpaperService.createFolder(name)
        WallpaperService.addItemToFolder(root.item.id, name)
        quickInput.text = ""
        root.closeRequested()
    }

    // Abre el menú anclado debajo de `anchor`, clampeado al área del app.
    function openFor(item, anchor) {
        root.item = item
        const p = anchor.mapToItem(root, 0, anchor.height)
        Qt.callLater(() => {
            box.x = Math.max(6, Math.min(p.x, root.width - box.width - 6))
            box.y = Math.max(6, Math.min(p.y, root.height - box.height - 6))
        })
    }

    function closeMenu() {
        root.item = null
    }
}