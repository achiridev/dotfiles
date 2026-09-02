// widgets/control/ControlButton.qml
// Botón de la barra (izquierda) que abre el Panel de Control de Quickshell.
// Sigue el mismo lenguaje visual que PowerButton/Clock: pill con bgModule,
// borderColor y hover animado.
import QtQuick
import qs.globals

Rectangle {
    id: root

    height: AppTheme.heightBar
    implicitWidth: 36

    border.color: AppTheme.borderColor
    border.width: 1

    radius: AppTheme.radius
    color: mouseArea.containsMouse ? AppTheme.bgModuleHover : AppTheme.bgModule

    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Text {
        anchors.centerIn: parent
        text: String.fromCodePoint(0xe732) // dev-archlinux
        color: mouseArea.containsMouse ? AppTheme.accent : AppTheme.textSecondary
        font.family: AppTheme.fontMono
        font.pixelSize: AppTheme.fontBase

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ControlState.togglePanel()
    }
}
