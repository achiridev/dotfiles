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

    // Ancla (el engranaje pulsado) y "ya posicionado": el box nace en (0,0) y
    // openFor lo coloca en el callLater, así que hasta entonces se oculta para
    // que no aparezca un frame en la esquina superior izquierda.
    property Item anchorItem: null
    property bool positioned: false

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
        visible: root.positioned
        width: 236
        height: contentLayout.implicitHeight + AppTheme.paddingLarge * 2
        radius: AppTheme.radiusLarge
        color: AppTheme.bgPopup
        border.width: 1
        border.color: AppTheme.borderColor
        z: 1
        // El alto depende del nº de carpetas, así que puede cambiar con el menú
        // ya abierto (layout sin resolver en el 1er frame, o una carpeta nueva):
        // se recalcula el volteo para que el panel no se salga del app.
        onHeightChanged: if (root.open)
            positionBox()

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

                    visible: WallpaperService.showHidden || folderName !== WallpaperService.hiddenFolder
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

    // Coloca el panel CENTRADO bajo el engranaje (con un pequeño hueco); si no
    // cabe debajo (última fila) voltea encima; siempre clampeado al área del app.
    function positionBox() {
        const m = 8
        const anchor = root.anchorItem
        let x
        let y
        if (anchor) {
            // mapToItem desde la esquina superior izquierda del engranaje: el
            // rect del slot no cambia con el scale de foco/hover, así el panel
            // no se mueve al pasar el mouse por encima.
            const a = anchor.mapToItem(root, 0, 0)
            x = a.x + anchor.width / 2 - box.width / 2
            const below = a.y + anchor.height + m
            const above = a.y - m - box.height
            y = below + box.height <= root.height ? below : (above >= 0 ? above : below)
        } else {
            x = (root.width - box.width) / 2
            y = (root.height - box.height) / 2
        }
        box.x = Math.max(m, Math.min(x, root.width - box.width - m))
        box.y = Math.max(m, Math.min(y, root.height - box.height - m))
        root.positioned = true
    }

    function openFor(item, anchor) {
        root.item = item
        root.anchorItem = anchor
        root.positioned = false
        // callLater: el box nace en (0,0) y solo se pinta cuando positioned.
        Qt.callLater(positionBox)
    }

    function closeMenu() {
        root.item = null
        root.anchorItem = null
    }
}