// widgets/wallpapers/FolderRail.qml
// Panel lateral del picker: carpetas (Todos / Sin carpeta / per-carpeta),
// creación de carpetas, filtro de etiquetas y estado del daemon. El contenido
// scrollea para que nunca se pierdan categorías; el estado queda anclado abajo.
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.globals
import qs.services

Rectangle {
    id: root

    width: AppTheme.wpSidebarWidth
    color: "transparent"
    Layout.fillHeight: true

    Rectangle {
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: 1
        color: AppTheme.borderColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: AppTheme.paddingBase
        spacing: AppTheme.paddingSmall

        // ---- Contenido scrolleable: carpetas + etiquetas ----
        Flickable {
            id: railScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: railColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: railColumn
                width: railScroll.width
                height: railColumn.implicitHeight
                spacing: AppTheme.paddingSmall

                // ---- Carpetas ----
                Text {
                    text: "Carpetas"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    font.weight: Font.Bold
                    color: AppTheme.textSecondary
                }

                FolderNavRow {
                    id: todosRow
                    label: "Todos"
                    folder: "all"
                    count: WallpaperService.totalCount
                    onClickedFolder: WallpaperService.activeFolder = "all"
                }

                FolderNavRow {
                    id: unfiledRow
                    label: "Sin carpeta"
                    folder: "unfiled"
                    count: WallpaperService.folderCount("unfiled")
                    onClickedFolder: WallpaperService.activeFolder = "unfiled"
                }

                Repeater {
                    model: WallpaperService.folders
                    delegate: FolderNavRow {
                        required property var modelData
                        visible: WallpaperService.showHidden || (modelData && modelData.name !== WallpaperService.hiddenFolder)
                        label: modelData ? modelData.name : ""
                        folder: modelData ? modelData.name : ""
                        count: WallpaperService.folderCount(modelData ? modelData.name : "")
                        deletable: modelData ? modelData.name !== WallpaperService.hiddenFolder : false

                        onClickedFolder: WallpaperService.activeFolder = folder
                        onDeleteRequested: WallpaperService.deleteFolder(folder)
                    }
                }

                // ---- Nueva carpeta ----
                Rectangle {
                    id: newFolderBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    radius: AppTheme.radiusSmall
                    color: Qt.alpha(AppTheme.fg, 0.05)

                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 8
                            rightMargin: 4
                        }
                        spacing: 4

                        TextInput {
                            id: newFolderInput
                            Layout.fillWidth: true
                            clip: true
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.fg
                            selectByMouse: true
                            onAccepted: root.addFolder()

                            Text {
                                anchors.fill: parent
                                visible: newFolderInput.length === 0
                                verticalAlignment: Text.AlignVCenter
                                text: "Nueva carpeta…"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                color: AppTheme.textTertiary
                            }
                        }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: addHover.containsMouse ? AppTheme.bgModuleHover : Qt.alpha(AppTheme.fg, 0.08)
                            Behavior on color {
                                ColorAnimation { duration: AppTheme.wpAnimFast }
                            }
                            MouseArea {
                                id: addHover
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addFolder()
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

                // ---- Etiquetas ----
                Text {
                    text: "Etiquetas"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    font.weight: Font.Bold
                    color: AppTheme.textSecondary
                }

                Flow {
                    id: tagsFlow
                    Layout.fillWidth: true
                    // Flow.implicitHeight = una sola fila; hay que fijar el alto
                    // a su contenido envuelto para que el Flickable lo calcule.
                    Layout.preferredHeight: Math.max(24, tagsFlow.contentHeight || 0)
                    spacing: AppTheme.paddingSmall

                    Repeater {
                        model: WallpaperService.tagNames
                        delegate: Rectangle {
                            required property var modelData
                            readonly property string tag: modelData
                            readonly property bool active: WallpaperService.activeTag === tag
                            implicitWidth: tagLabel.implicitWidth + AppTheme.paddingLarge * 2
                            height: 24
                            radius: 12
                            color: active ? AppTheme.accent
                                          : (tagHover.containsMouse ? AppTheme.surface : Qt.alpha(AppTheme.fg, 0.05))
                            Behavior on color {
                                ColorAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
                            }
                            Text {
                                id: tagLabel
                                anchors.centerIn: parent
                                text: tag
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontTiny
                                font.weight: Font.Bold
                                color: active ? AppTheme.bg : AppTheme.textSecondary
                            }
                            MouseArea {
                                id: tagHover
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WallpaperService.activeTag = (tag === WallpaperService.activeTag) ? "" : tag
                            }
                        }
                    }
                }
            }
        }

        // ---- Estado del daemon (anclado, siempre visible) ----
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            spacing: AppTheme.paddingSmall

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: WallpaperService.daemonUp ? AppTheme.success : AppTheme.critical
                Behavior on color {
                    ColorAnimation { duration: AppTheme.wpAnimFast }
                }
            }
            Text {
                text: WallpaperService.daemonUp ? "waywallen activo" : "waywallen fuera"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                color: AppTheme.textSecondary
            }
        }
    }

    function addFolder() {
        if (newFolderInput.text.length > 0) {
            WallpaperService.createFolder(newFolderInput.text)
            newFolderInput.text = ""
        }
    }
}