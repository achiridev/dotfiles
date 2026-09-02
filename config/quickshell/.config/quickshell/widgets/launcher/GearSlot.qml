// widgets/launcher/GearSlot.qml
// Diente del engranaje: celda polar (icono + nombre) que orbita la corona.
// Vive como hijo del `dial` (disc) del Gear principal y de los satélites, así
// que su posición local es polar respecto al centro del dial que lo contiene.
// El contenido (`app`) se re-enlaza de forma reactiva cuando el anillo rota.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.globals

Rectangle {
    id: root

    required property var app
    property real angleDeg: -90
    property real orbitRadius: 300
    property real cellW: 96
    property real cellH: 96
    property real iconPx: 44
    property bool showLabel: true
    property bool hovered: false
    // Indica el DIENTE SUPERIOR (= app seleccionada/foco del anillo).
    property bool isFocus: false
    // Contra-rotación del contenido (icono + label) para que quede vertical
    // a la pantalla aunque el dial/satélite que lo contiene esté rotado.
    property real counterRot: 0

    signal clicked(var app)

    // Icono resuelto del diente: si el nombre del .desktop no existe en el
    // tema activo de Qt, cae a un genérico en vez del cuadro morado y el
    // "Could not load icon" de Quickshell.
    readonly property string resolvedIcon: {
        const name = root.app && root.app.icon ? String(root.app.icon).trim() : "";
        if (name !== "" && Quickshell.hasThemeIcon(name))
            return Quickshell.iconPath(name);
        return Quickshell.iconPath("application-x-executable");
    }

    width: root.cellW
    height: root.cellH
    radius: AppTheme.radiusLarge
    // Posición polar respecto al centro del dial (0,0 de su parent dial).
    x: Math.cos(root.angleDeg * Math.PI / 180) * root.orbitRadius - root.width / 2
    y: Math.sin(root.angleDeg * Math.PI / 180) * root.orbitRadius - root.height / 2
    z: root.hovered ? 10 : (root.isFocus ? 5 : 1)
    scale: root.hovered ? 1.08 : (root.isFocus ? 1.04 : 1)
    color: root.isFocus ? Qt.alpha(AppTheme.color4, 0.16) : root.hovered ? AppTheme.surface : Qt.alpha(AppTheme.fg, 0.04)
    border.width: root.isFocus ? 2 : 1
    border.color: root.isFocus ? Qt.alpha(AppTheme.color4, 1) : root.hovered ? Qt.alpha(AppTheme.accent, 0.9) : Qt.alpha(AppTheme.borderColor, 0.35)

    Item {
        anchors.centerIn: parent
        rotation: root.counterRot
        width: root.width - 16

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 5

            IconImage {
                id: slotIcon

                width: root.iconPx
                height: root.iconPx
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.app !== null
                source: root.resolvedIcon
            }

            Text {
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.app ? root.app.name : ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                clip: true
                visible: root.showLabel
                font.family: AppTheme.fontMono
                font.pixelSize: 12
                font.weight: Font.Bold
                color: AppTheme.fg
            }

        }

    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: {
            if (containsMouse)
                root.hovered = true;
            else
                root.hovered = false;
        }
        onClicked: root.clicked(root.app)
        onWheel: (event) => {
            event.accepted = true;
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }

    }

    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }

    }

    Behavior on border.color {
        ColorAnimation {
            duration: 150
        }

    }

}
