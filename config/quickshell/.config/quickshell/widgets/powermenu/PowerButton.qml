// widgets/PowerMenu/PowerButton.qml
import QtQuick
import QtQuick.Layouts
import qs.globals
import qs.services

Rectangle {
    id: root

    // Propiedades personalizables para reutilizar en cualquier panel
    property string icon: String.fromCodePoint(0xf011) || "⏻"
    property color iconColor: AppTheme.critical
    property var onClicked: () => PowerService.openPowerMenu()

    // Dimensiones dinámicas
    height: AppTheme.heightBar
    implicitWidth: 48

    border.color: AppTheme.borderColor
    border.width: 1

    radius: AppTheme.radius
    color: mouseArea.containsMouse ? AppTheme.bgModuleHover : AppTheme.bgModule

    // Animación suave al hacer hover
    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
        font.family: AppTheme.fontMono
        font.pixelSize: AppTheme.fontLarge
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.onClicked()
    }
}
