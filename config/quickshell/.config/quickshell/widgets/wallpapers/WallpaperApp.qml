// widgets/wallpapers/WallpaperApp.qml
// Layout raíz del picker: header (título, búsqueda, shuffle, cerrar), fila de
// navegación (tipo + controles), sidebar de carpetas y grid. Manejo global de
// teclado: Esc cierra, flechas navegan el grid, Enter aplica.
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.globals
import qs.services

Item {
    id: root

    implicitWidth: AppTheme.wpWindowWidth
    implicitHeight: AppTheme.wpWindowHeight
    focus: true

    onVisibleChanged: {
        if (visible) {
            wallpaperGrid.currentIndex = 0
            forceActiveFocus()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: AppTheme.paddingLarge
        spacing: AppTheme.paddingBase

        // ==========================================================
        // HEADER
        // ==========================================================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: AppTheme.paddingSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                Text {
                    text: "Wallpapers"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontLarge
                    font.weight: Font.Bold
                    color: AppTheme.fg
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.filterSummary.text
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textSecondary
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                // ---- Búsqueda ----
                Rectangle {
                    id: searchBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: AppTheme.radius
                    color: Qt.alpha(AppTheme.fg, 0.05)
                    border.width: 1
                    border.color: searchInput.activeFocus ? Qt.alpha(AppTheme.accent, 0.6) : AppTheme.borderColor

                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: AppTheme.paddingBase
                            rightMargin: AppTheme.paddingSmall
                        }
                        spacing: AppTheme.paddingSmall

                        Text {
                            text: "󰭎"
                            font.family: AppTheme.fontMono
                            font.pixelSize: AppTheme.fontBase
                            color: searchInput.activeFocus ? AppTheme.accent : AppTheme.textSecondary
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            clip: true
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.fg
                            selectByMouse: true
                            text: WallpaperService.searchText
                            onTextChanged: WallpaperService.searchText = text

                            Text {
                                anchors.fill: parent
                                visible: searchInput.length === 0
                                verticalAlignment: Text.AlignVCenter
                                text: "Buscar…"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                color: AppTheme.textTertiary
                            }
                        }

                        Text {
                            visible: searchInput.length > 0
                            text: "✕"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            color: AppTheme.textSecondary
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchInput.text = ""
                            }
                        }
                    }
                }

                // ---- Shuffle ----
                Rectangle {
                    id: shuffleBtn
                    readonly property bool active: WallpaperService.shuffle
                    Layout.preferredWidth: shuffleLabel.implicitWidth + AppTheme.paddingLarge * 2
                    Layout.preferredHeight: 34
                    radius: AppTheme.radius
                    color: active ? AppTheme.accent : (shuffleHover.containsMouse ? AppTheme.surface : Qt.alpha(AppTheme.fg, 0.05))
                    Behavior on color {
                        ColorAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
                    }
                    Text {
                        id: shuffleLabel
                        anchors.centerIn: parent
                        text: "Aleatorio"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        font.weight: Font.Bold
                        color: shuffleBtn.active ? AppTheme.bg : AppTheme.fg
                    }
                    MouseArea {
                        id: shuffleHover
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WallpaperService.setShuffle(!WallpaperService.shuffle)
                    }
                }

                // ---- Cerrar ----
                Rectangle {
                    id: closeBtn
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: AppTheme.radius
                    color: closeHover.containsMouse ? AppTheme.critical : Qt.alpha(AppTheme.fg, 0.05)
                    Behavior on color {
                        ColorAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        font.weight: Font.Bold
                        color: closeHover.containsMouse ? AppTheme.bg : AppTheme.fg
                    }
                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WallpaperService.close()
                    }
                }
            }

            // ---- Fila de tipo ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [["Todos", "all"], ["Escena", "scene"], ["Video", "video"], ["Web", "web"]]
                    delegate: typeChip
                }

                Item { Layout.fillWidth: true }

                ActionButton {
                    glyph: "◀"
                    label: "Anterior"
                    enabled: !WallpaperService.cmdBusy && !WallpaperService.applyingId
                    onClicked: WallpaperService.previous()
                }

                ActionButton {
                    glyph: "▶"
                    label: "Siguiente"
                    enabled: !WallpaperService.cmdBusy && !WallpaperService.applyingId
                    onClicked: WallpaperService.next()
                }

                ActionButton {
                    glyph: "⟳"
                    label: "Rescan"
                    enabled: !WallpaperService.cmdBusy && !WallpaperService.applyingId
                    onClicked: WallpaperService.rescan()
                }
            }
        }

        // ==========================================================
        // CUERPO: sidebar + grid
        // ==========================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: AppTheme.paddingLarge

            FolderRail {}

            Rectangle {
                id: mainPane
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: AppTheme.radius
                color: Qt.alpha(AppTheme.fg, 0.03)
                border.width: 1
                border.color: AppTheme.borderColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: AppTheme.paddingBase
                    spacing: AppTheme.paddingSmall

                    // ---- Barra de estado ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: AppTheme.paddingBase

                        Text {
                            id: resultCount
                            text: WallpaperService.visibleItems.length + " fondos"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            font.weight: Font.Bold
                            color: AppTheme.fg
                        }

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            visible: WallpaperService.loading
                            color: AppTheme.accent
                            RotationAnimation on rotation {
                                from: 0; to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: root.currentInfo
                            elide: Text.ElideRight
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: WallpaperService.applyFailed ? AppTheme.critical : AppTheme.textSecondary
                        }
                    }

                    WallpaperGrid {
                        id: wallpaperGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onAskMenu: assignMenu.openFor(item, anchor)
                    }
                }
            }
        }
    }

    // ==========================================================
    // MENÚ DE ASIGNACIÓN (overlay)
    // ==========================================================
    FolderAssignMenu {
        id: assignMenu
        anchors.fill: parent
        onCloseRequested: assignMenu.item = null
    }

    // ==========================================================
    // TECLADO
    // ==========================================================
    Keys.onPressed: event => {
        if (assignMenu.open) {
            if (event.key === Qt.Key_Escape)
                assignMenu.item = null
            event.accepted = true
            return
        }
        switch (event.key) {
        case Qt.Key_Escape:
            WallpaperService.close()
            event.accepted = true
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            wallpaperGrid.applyCurrent()
            event.accepted = true
            break
        case Qt.Key_Up:
            wallpaperGrid.moveCurrentIndexUp()
            event.accepted = true
            break
        case Qt.Key_Down:
            wallpaperGrid.moveCurrentIndexDown()
            event.accepted = true
            break
        case Qt.Key_Left:
            wallpaperGrid.moveCurrentIndexLeft()
            event.accepted = true
            break
        case Qt.Key_Right:
            wallpaperGrid.moveCurrentIndexRight()
            event.accepted = true
            break
        }
    }

    // ==========================================================
    // HELPERS
    // ==========================================================
    readonly property QtObject filterSummary: QtObject {
        readonly property string text: {
            const parts = []
            if (WallpaperService.activeFolder !== "all")
                parts.push(WallpaperService.activeFolder === "unfiled" ? "Sin carpeta" : WallpaperService.activeFolder)
            if (WallpaperService.activeType !== "all")
                parts.push(root.typeLabel(WallpaperService.activeType))
            if (WallpaperService.activeTag)
                parts.push("#" + WallpaperService.activeTag)
            return parts.length ? parts.join(" · ") : "Todos los fondos"
        }
    }

    readonly property string currentInfo: {
        if (WallpaperService.applyFailed)
            return "No se pudo aplicar el wallpaper"
        if (WallpaperService.applyingId)
            return "Aplicando…"
        if (WallpaperService.currentId) {
            const name = WallpaperService.nameForId(WallpaperService.currentId)
            return "Actual: " + (name || WallpaperService.currentId)
        }
        return "Sin wallpaper activo"
    }

    function typeLabel(type) {
        if (type === "scene") return "Escena"
        if (type === "video") return "Video"
        if (type === "web") return "Web"
        return ""
    }

    // ==========================================================
    // COMPONENTES REUTILIZABLES
    // ==========================================================
    Component {
        id: typeChip
        Rectangle {
            required property var modelData
            readonly property string chipType: modelData ? modelData[1] : ""
            readonly property string chipLabel: modelData ? modelData[0] : ""
            readonly property bool active: WallpaperService.activeType === chipType

            Layout.preferredWidth: chipText.implicitWidth + AppTheme.paddingLarge * 2
            Layout.preferredHeight: 26
            radius: 13
            color: active ? AppTheme.accent : (chipHover.containsMouse ? AppTheme.surface : Qt.alpha(AppTheme.fg, 0.05))
            Behavior on color {
                ColorAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
            }

            Text {
                id: chipText
                anchors.centerIn: parent
                text: chipLabel
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: active ? AppTheme.bg : AppTheme.textSecondary
            }

            MouseArea {
                id: chipHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: WallpaperService.activeType = (chipType === WallpaperService.activeType) ? "all" : chipType
            }
        }
    }
}