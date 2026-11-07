// widgets/clipboard/ClipboardPreview.qml
//
// Vista previa de la entrada seleccionada. Componente STATELESS: recibe
// `entry` (metadatos de la lista) y `preview` (contenido decodificado).
// La decodificación y la caché de miniaturas viven en ClipboardService.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.globals
import qs.widgets.clipboard

Rectangle {
    id: root

    property var entry: null
    property var preview: null

    readonly property bool hasEntry: entry !== null && entry !== undefined
    readonly property string kind: hasEntry ? entry.kind : ""
    readonly property bool isLoading: preview ? preview.loading : false
    readonly property bool hasImage: kind === "image" && preview && preview.image !== ""
    readonly property bool isText: kind === "text"
    readonly property bool isBinary: kind === "binary"

    readonly property color kindColor: kind === "image" ? ClipboardStyle.imageKindColor
        : kind === "binary" ? ClipboardStyle.binaryKindColor
        : ClipboardStyle.textKindColor

    readonly property string kindIcon: kind === "image" ? String.fromCodePoint(0xf03e)
        : kind === "binary" ? String.fromCodePoint(0xf0c5)
        : String.fromCodePoint(0xf0f6)

    radius: ClipboardStyle.rowRadius
    color: ClipboardStyle.previewBg
    border.width: 1
    border.color: ClipboardStyle.divider
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ClipboardStyle.previewPadding
        spacing: AppTheme.paddingBase

        // ── Cabecera: tipo + metadatos ───────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: AppTheme.paddingSmall

            Text {
                text: root.kindIcon
                visible: root.hasEntry
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                color: root.kindColor
            }

            Text {
                text: root.hasEntry ? root.entry.kindLabel : "Vista previa"
                font.family: AppTheme.fontLayout
                font.pixelSize: ClipboardStyle.metaSize
                font.weight: Font.Bold
                color: root.hasEntry ? root.kindColor : ClipboardStyle.textTertiary
            }

            Text {
                Layout.fillWidth: true
                text: root.hasEntry ? root.entry.meta : ""
                elide: Text.ElideRight
                font.family: AppTheme.fontMono
                font.pixelSize: ClipboardStyle.metaSize
                color: ClipboardStyle.textTertiary
            }

            Text {
                visible: root.hasEntry && root.preview && root.preview.mime !== ""
                text: root.preview ? root.preview.mime : ""
                elide: Text.ElideRight
                font.family: AppTheme.fontMono
                font.pixelSize: ClipboardStyle.metaSize
                color: ClipboardStyle.textTertiary
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: ClipboardStyle.divider
        }

        // ── Cuerpo ───────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Imagen (miniatura cacheada, cargada async y acotada).
            Image {
                id: image
                anchors.fill: parent
                visible: root.hasImage
                source: root.hasImage ? root.preview.image : ""
                sourceSize.width: ClipboardStyle.imagePreviewMaxPx
                sourceSize.height: ClipboardStyle.imagePreviewMaxPx
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                smooth: true
                mipmap: false
            }

            // Texto: seleccionable y con scroll para textos largos.
            Flickable {
                id: textFlick
                anchors.fill: parent
                visible: root.isText
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: textEdit.implicitHeight

                TextEdit {
                    id: textEdit
                    width: textFlick.width
                    readOnly: true
                    selectByMouse: true
                    activeFocusOnPress: false
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                    selectionColor: ClipboardStyle.selectionColor
                    selectedTextColor: ClipboardStyle.textPrimary
                    font.family: AppTheme.fontMono
                    font.pixelSize: ClipboardStyle.textPreviewSize
                    color: ClipboardStyle.textPrimary
                    text: {
                        if (!root.preview) return ""
                        if (root.preview.text !== "") return root.preview.text
                        return root.isLoading ? "Cargando…" : "(entrada vacía)"
                    }
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

            // Binario: metadatos + aviso. Se restaurará con su MIME real.
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width * 0.8
                visible: root.isBinary && !root.isLoading
                spacing: AppTheme.paddingBase

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: String.fromCodePoint(0xf0c5)
                    font.family: AppTheme.fontMono
                    font.pixelSize: 42
                    color: ClipboardStyle.binaryKindColor
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.entry ? root.entry.format : "BIN"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontLarge
                    font.weight: Font.Bold
                    color: ClipboardStyle.textPrimary
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.preview && root.preview.mime !== ""
                        ? root.preview.mime
                        : "Contenido binario"
                    font.family: AppTheme.fontMono
                    font.pixelSize: ClipboardStyle.metaSize
                    color: ClipboardStyle.textSecondary
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Se restaurará al portapapeles con su tipo original."
                    font.family: AppTheme.fontLayout
                    font.pixelSize: ClipboardStyle.hintSize
                    color: ClipboardStyle.textTertiary
                }
            }

            // Sin entrada seleccionada.
            ColumnLayout {
                anchors.centerIn: parent
                visible: !root.hasEntry
                spacing: AppTheme.paddingBase

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: String.fromCodePoint(0xf0c5)
                    font.family: AppTheme.fontMono
                    font.pixelSize: 42
                    color: ClipboardStyle.textTertiary
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Selecciona una entrada"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontBase
                    color: ClipboardStyle.textSecondary
                }
            }

            // Cargando (solo cuando no hay contenido que mostrar todavía).
            Text {
                anchors.centerIn: parent
                visible: root.hasEntry && root.isLoading
                    && !root.hasImage
                    && !(root.isText && root.preview && root.preview.text !== "")
                text: "Cargando vista previa…"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                color: ClipboardStyle.textTertiary
            }

            // Error de decodificación (miniaturas corruptas, etc.).
            Text {
                anchors.centerIn: parent
                visible: root.preview && root.preview.error !== ""
                text: root.preview ? root.preview.error : ""
                wrapMode: Text.WordWrap
                width: parent.width * 0.8
                horizontalAlignment: Text.AlignHCenter
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                color: ClipboardStyle.danger
            }

            // La imagen cargó pero Qt no pudo decodificarla.
            Text {
                anchors.centerIn: parent
                visible: root.hasImage && image.status === Image.Error
                text: "No se pudo mostrar la imagen"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                color: ClipboardStyle.danger
            }
        }
    }
}
