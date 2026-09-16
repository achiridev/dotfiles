// widgets/wallpapers/WallpaperApp.qml
// Layout raíz del picker dividido en dos secciones: la caja izquierda agrupa
// toda la configuración (título, búsqueda, tipo, carpetas, estado) y la
// derecha muestra solo las previsualizaciones de los fondos, al aire, sin caja.
// Manejo global de teclado: Esc cierra, flechas navegan el grid, Enter aplica.
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.globals
import qs.services

Item {
    id: root

    focus: true

    onVisibleChanged: {
        if (visible)
            forceActiveFocus()
    }

    RowLayout {
        anchors.fill: parent
        spacing: AppTheme.paddingLarge

        // ==========================================================
        // SECCIÓN IZQUIERDA: caja con todas las opciones
        // ==========================================================
        Rectangle {
            id: leftBox
            Layout.preferredWidth: AppTheme.wpSidebarWidth + AppTheme.paddingLarge * 2 + 40
            Layout.fillHeight: true
            radius: AppTheme.radiusLarge
            color: AppTheme.bgPopup
            border.width: 1
            border.color: AppTheme.borderColor
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: AppTheme.paddingLarge
                spacing: AppTheme.paddingBase

                // ---- Título + resumen del filtro ----
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

                // ---- Búsqueda + Rescan + Cerrar ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingSmall

                    Rectangle {
                        id: searchBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
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

                    ActionButton {
                        glyph: "⟳"
                        label: "Rescan"
                        enabled: !WallpaperService.cmdBusy && !WallpaperService.applyingId
                        onClicked: WallpaperService.rescan()
                    }

                    Rectangle {
                        id: closeBtn
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
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

                // ---- Fila de tipo (wrap en Flow) ----
                Flow {
                    id: typesFlow
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(26, typesFlow.contentHeight || 0)
                    spacing: 6

                    Repeater {
                        model: [["Todos", "all"], ["Escena", "scene"], ["Video", "video"], ["Web", "web"]]
                        delegate: typeChip
                    }
                }

                // ---- Separador ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: AppTheme.borderColor
                }

                // ---- Carpetas + etiquetas + estado del daemon ----
                Rectangle {
                    id: foldersPanel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 240
                    radius: AppTheme.radius
                    color: AppTheme.surface
                    border.width: 1
                    border.color: AppTheme.borderColor

                    FolderRail {
                        anchors.fill: parent
                    }
                }

                // ---- Barra de estado ----
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBottom
                    spacing: AppTheme.paddingSmall

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
            }
        }

        // ==========================================================
        // SECCIÓN DERECHA: tablero de engranajes al aire. El host rellena el
        // hueco (invisible) y el tablero se escala para llenarlo dejando un
        // margen real de `wpGearHostPad` por cada lado (medible y ajustable).
        // ==========================================================
        Item {
            id: gearHost
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                visible: WallpaperService.boardCount === 0
                anchors.centerIn: parent
                text: "Sin resultados"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                color: AppTheme.textSecondary
            }

            WallpaperGear {
                id: wallpaperGear
                visible: WallpaperService.boardCount > 0
                anchors.centerIn: parent
                scale: Math.max(0.2, Math.min(
                    (gearHost.width - AppTheme.wpGearHostPad * 2) / wallpaperGear.implicitWidth,
                    (gearHost.height - AppTheme.wpGearHostPad * 2) / wallpaperGear.implicitHeight))

                Behavior on scale {
                    NumberAnimation { duration: AppTheme.wpAnimBase; easing.type: Easing.OutCubic }
                }

                onApplyRequested: item => {
                    if (item)
                        WallpaperService.apply(item.id)
                }
                onMenuRequested: (item, anchor) => assignMenu.openFor(item, anchor)
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
        case Qt.Key_Enter: {
            const focus = WallpaperService.focusItem()
            if (focus)
                WallpaperService.apply(focus.id)
            event.accepted = true
            break
        }
        case Qt.Key_Left:
            WallpaperService.navigate(-1, 0)
            event.accepted = true
            break
        case Qt.Key_Right:
            WallpaperService.navigate(1, 0)
            event.accepted = true
            break
        case Qt.Key_Up:
            WallpaperService.navigate(0, -1)
            event.accepted = true
            break
        case Qt.Key_Down:
            WallpaperService.navigate(0, 1)
            event.accepted = true
            break
        case Qt.Key_H:
            WallpaperService.showHidden = !WallpaperService.showHidden
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

            implicitWidth: chipText.implicitWidth + AppTheme.paddingLarge * 2
            implicitHeight: 26
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