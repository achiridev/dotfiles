// widgets/wallpapers/LazyImage.qml
// Imagen perezosa para grids: carga async a tamaño acotado, sin mipmaps y con
// fade-in. La fuente es siempre el thumb en cache (los items sin preview real
// tienen un thumb placeholder), así no se cargan previews originales pesados
// (864×864/gifs) ni se disparan warnings por archivos inexistentes.
import QtQuick

Item {
    id: root

    property alias source: image.source
    property alias fillMode: image.fillMode
    property alias status: image.status
    property alias imageOpacity: image.opacity
    property alias smooth: image.smooth
    property real maxSourceWidth: 512

    Image {
        id: image

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: false
        mipmap: false
        sourceSize.width: root.maxSourceWidth
        sourceSize.height: root.maxSourceWidth * 9 / 16

        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }
}