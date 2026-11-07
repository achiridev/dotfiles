// widgets/clipboard/ClipboardSearchBar.qml
//
// Buscador del portapapeles. Es un componente CONTROLADO: no guarda el query
// en un servicio, solo refleja `text` y emite `textEdited`. Toda la navegación
// por teclado del panel se centraliza aquí porque es el widget que tiene el
// foco exclusivo.
import QtQuick
import QtQuick.Layouts

import qs.globals
import qs.widgets.clipboard

Rectangle {
    id: root

    property string text: ""
    property string placeholder: "Buscar en el historial…"
    property bool busy: false

    readonly property bool hasText: input.text.length > 0

    signal textEdited(string value)
    signal navigate(int delta)
    signal pageNavigate(int delta)
    signal firstRequested()
    signal lastRequested()
    signal acceptRequested()
    signal dismissRequested()
    signal deleteRequested()

    implicitHeight: ClipboardStyle.searchHeight
    radius: ClipboardStyle.searchRadius
    color: input.activeFocus ? ClipboardStyle.searchBgFocused : ClipboardStyle.searchBg
    border.width: 1
    border.color: input.activeFocus ? ClipboardStyle.searchBorderFocused : ClipboardStyle.searchBorder

    Behavior on color { ColorAnimation { duration: ClipboardStyle.animFast } }
    Behavior on border.color { ColorAnimation { duration: ClipboardStyle.animFast } }

    function forceFocus() {
        input.forceActiveFocus()
        input.cursorPosition = input.text.length
    }

    function clearText() {
        input.text = ""
    }

    // El widget es controlado: si el padre cambia `text` (limpiar al abrir,
    // restaurar un query…) se refleja en el TextInput sin romper el binding.
    onTextChanged: {
        if (input.text !== root.text) {
            input.text = root.text
            input.cursorPosition = input.text.length
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: AppTheme.paddingLarge
        anchors.rightMargin: AppTheme.paddingBase
        spacing: AppTheme.paddingBase

        Text {
            text: String.fromCodePoint(0xf002) // lupa
            font.family: AppTheme.fontMono
            font.pixelSize: AppTheme.fontBase
            color: input.activeFocus ? ClipboardStyle.accent : ClipboardStyle.textTertiary
        }

        TextInput {
            id: input

            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter

            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontBase
            color: ClipboardStyle.textPrimary
            selectionColor: ClipboardStyle.selectionColor
            selectedTextColor: ClipboardStyle.textPrimary
            clip: true

            // Placeholder dibujado aparte (TextInput no tiene uno nativo).
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                visible: input.text.length === 0
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                color: ClipboardStyle.textTertiary
            }

            onTextChanged: {
                if (text !== root.text)
                    root.textEdited(text)
            }

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Up:
                    root.navigate(-1)
                    event.accepted = true
                    break
                case Qt.Key_Down:
                    root.navigate(1)
                    event.accepted = true
                    break
                case Qt.Key_PageUp:
                    root.pageNavigate(-1)
                    event.accepted = true
                    break
                case Qt.Key_PageDown:
                    root.pageNavigate(1)
                    event.accepted = true
                    break
                case Qt.Key_Home:
                    if (event.modifiers & Qt.ControlModifier) {
                        root.firstRequested()
                        event.accepted = true
                    }
                    break
                case Qt.Key_End:
                    if (event.modifiers & Qt.ControlModifier) {
                        root.lastRequested()
                        event.accepted = true
                    }
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.acceptRequested()
                    event.accepted = true
                    break
                case Qt.Key_Escape:
                    if (root.hasText) {
                        root.clearText()
                    } else {
                        root.dismissRequested()
                    }
                    event.accepted = true
                    break
                case Qt.Key_Delete:
                    // Ctrl+Supr siempre; Supr solo con el buscador vacío
                    // (si hay texto, Supr debe editar la búsqueda).
                    if ((event.modifiers & Qt.ControlModifier) || !root.hasText) {
                        root.deleteRequested()
                        event.accepted = true
                    }
                    break
                }
            }
        }

        // Indicador de refresco discreto (sin animaciones nuevas).
        Text {
            visible: root.busy
            text: "…"
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontBase
            color: ClipboardStyle.textTertiary
        }

        // Botón limpiar búsqueda.
        Rectangle {
            visible: root.hasText
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: AppTheme.radiusSmall
            color: clearMa.containsMouse ? ClipboardStyle.buttonHover : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: clearMa.containsMouse ? ClipboardStyle.textPrimary : ClipboardStyle.textTertiary
            }

            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.clearText()
                    root.forceFocus()
                }
            }
        }
    }
}
