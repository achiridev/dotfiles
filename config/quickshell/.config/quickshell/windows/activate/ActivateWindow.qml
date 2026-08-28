// windows/activate/ActivateWindow.qml
// Marca de agua estilo "Activar Windows" en la esquina inferior-derecha.
// La capa y visibilidad dependen solo de AppState.activateMode (0/1/2).
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.globals

Scope {
    id: activateScope

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: root
                required property var modelData

                screen: modelData
                visible: AppState.activateMode > 0

                // 1: sobre el wallpaper (Background) y detrás de las ventanas
                // 2: delante de todo (incluido el bar, que es WlrLayer.Top)
                WlrLayershell.layer: AppState.activateMode === 2
                    ? WlrLayer.Top
                    : WlrLayer.Bottom

                WlrLayershell.namespace: "quickshell:activate"

                // no reservar espacio ni bloquear interacción
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                mask: Region {}

                anchors {
                    right: true
                    bottom: true
                }

                margins {
                    right: AppState.activateMargin
                    bottom: AppState.activateMargin
                }

                // el PanelWindow NO autosizea al contenido (default 100x100):
                // hay que fijar el tamaño al del texto para evitar el clipeo
                implicitWidth: activateColumn.width
                implicitHeight: activateColumn.implicitHeight

                Column {
                    id: activateColumn
                    width: Math.max(activateMainText.implicitWidth, activateSubText.implicitWidth)

                    Text {
                        id: activateMainText
                        anchors.right: parent.right
                        text: qsTr("Activar Linux")
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppState.activateTextSize
                        color: "#ffffff"
                        opacity: 0.75
                    }

                    Text {
                        id: activateSubText
                        anchors.right: parent.right
                        text: qsTr("I use arch btw")
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppState.activateSubTextSize
                        color: "#ffffff"
                        opacity: 0.55
                    }
                }
            }
        }
    }
}