// widgets/clipboard/ClipboardView.qml
//
// Composición visual del gestor. Es el ÚNICO archivo que cablea los widgets
// con ClipboardState/ClipboardService. Para un rediseño completo se puede
// reemplazar este archivo (o apuntar el Loader de la ventana a otra vista) sin
// tocar la lógica del portapapeles.
import QtQuick
import QtQuick.Layouts

import qs.globals
import qs.services
import qs.widgets.clipboard

Rectangle {
    id: root

    readonly property string countText: {
        if (!ClipboardService.ready) return ""
        if (ClipboardService.query !== "")
            return ClipboardService.filteredCount + " de " + ClipboardService.totalCount
        return ClipboardService.totalCount + " elementos · " + ClipboardService.imageCount + " imágenes"
    }

    color: ClipboardStyle.panelColor
    radius: ClipboardStyle.panelRadius
    border.width: 1
    border.color: ClipboardStyle.panelBorder
    clip: true

    function focusSearch() {
        searchBar.forceFocus()
    }

    // Bloquea clicks en zonas vacías de la tarjeta para que no lleguen al
    // MouseArea de "click fuera" de la ventana. Los hijos interactivos
    // (filas, buscador, scroll) están por encima y reciben antes.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => mouse.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ClipboardStyle.panelPadding
        spacing: ClipboardStyle.sectionSpacing

        // ════════════════════════════════════════════════════════════
        // CABECERA
        // ════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: AppTheme.paddingBase

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: AppTheme.radiusSmall
                color: Qt.alpha(ClipboardStyle.accent, 0.14)
                border.width: 1
                border.color: Qt.alpha(ClipboardStyle.accent, 0.32)

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xf0c5) // portapapeles
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontBase
                    color: ClipboardStyle.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "Portapapeles"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: ClipboardStyle.titleSize
                    font.weight: Font.Bold
                    color: ClipboardStyle.textPrimary
                }

                Text {
                    text: root.countText
                    elide: Text.ElideRight
                    font.family: AppTheme.fontLayout
                    font.pixelSize: ClipboardStyle.metaSize
                    color: ClipboardStyle.textTertiary
                }
            }

            Text {
                visible: ClipboardService.loading
                text: "Actualizando…"
                font.family: AppTheme.fontLayout
                font.pixelSize: ClipboardStyle.metaSize
                color: ClipboardStyle.textTertiary
            }

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: AppTheme.radiusSmall
                color: refreshMa.containsMouse ? ClipboardStyle.buttonHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xf021) // refrescar
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontBase
                    color: refreshMa.containsMouse ? ClipboardStyle.textPrimary : ClipboardStyle.textTertiary
                }

                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ClipboardService.refresh()
                }
            }
        }

        // ════════════════════════════════════════════════════════════
        // BUSCADOR
        // ════════════════════════════════════════════════════════════
        ClipboardSearchBar {
            id: searchBar

            Layout.fillWidth: true
            text: ClipboardService.query
            busy: ClipboardService.loading

            onTextEdited: value => ClipboardState.setQuery(value)
            onNavigate: delta => ClipboardState.move(delta)
            onPageNavigate: delta => ClipboardState.movePage(delta)
            onFirstRequested: ClipboardState.selectFirst()
            onLastRequested: ClipboardState.selectLast()
            onAcceptRequested: ClipboardState.activateCurrent()
            onDismissRequested: ClipboardState.close()
            onDeleteRequested: ClipboardState.deleteCurrent()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: ClipboardStyle.divider
        }

        // ════════════════════════════════════════════════════════════
        // CUERPO: LISTA + VISTA PREVIA
        // ════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                visible: ClipboardService.filteredCount > 0
                spacing: ClipboardStyle.sectionPadding

                ClipboardList {
                    Layout.preferredWidth: ClipboardStyle.listWidth
                    Layout.fillHeight: true
                    selectedIndex: ClipboardState.selectedIndex

                    onActivated: id => ClipboardState.activate(id)
                    onDeleteRequested: id => ClipboardService.remove(id)
                    onHovered: id => ClipboardState.hover(id)
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: ClipboardStyle.divider
                }

                ClipboardPreview {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    entry: ClipboardState.currentEntry
                    preview: ClipboardService.preview
                }
            }

            ClipboardEmptyState {
                anchors.fill: parent
                visible: ClipboardService.filteredCount === 0
                query: ClipboardService.query
                loading: ClipboardService.loading
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: ClipboardStyle.divider
        }

        // ════════════════════════════════════════════════════════════
        // PIE
        // ════════════════════════════════════════════════════════════
        ClipboardFooter {
            Layout.fillWidth: true
            count: ClipboardService.totalCount
            confirmClear: ClipboardState.confirmClear
            error: ClipboardService.error
            onClearRequested: ClipboardState.requestClear()
        }
    }
}
