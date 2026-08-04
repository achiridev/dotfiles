// widgets/PowerMenu/PowerButton.qml
import QtQuick
import QtQuick.Layouts
import qs.globals
import qs.services

Rectangle {
    id: root

    // Propiedades personalizables para reutilizar en cualquier panel
    property string icon: String.fromCodePoint(0xf011) || "⏻"
    property color iconColor: AppTheme.colors.red || "#f36b88"
    property color hoverBg: Qt.alpha(AppTheme.colors.surface || "#313244", 0.6)
    property var onClicked: () => PowerService.openPowerMenu()

    // Dimensiones dinámicas
    Layout.fillHeight: true
    implicitWidth: 48

    border.color: AppTheme.borderColor
    border.width: 1

    radius: AppTheme.radius || 6
    color: mouseArea.containsMouse ? hoverBg : AppTheme.bgModule

    // Animación suave al hacer hover
    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
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
