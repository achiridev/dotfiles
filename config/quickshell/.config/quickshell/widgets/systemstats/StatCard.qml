// widgets/systemstats/StatCard.qml
import QtQuick
import QtQuick.Layouts
import qs.globals

// Tarjeta con ring gauge (arco 270°) para CPU / RAM / GPU: porcentaje al
// centro, título debajo y badge de temperatura opcional. El color lo decide
// el padre vía `accentColor` (statusColor para temps, usageColor para %).
ColumnLayout {
    id: root

    property string title: "CPU"
    property int usage: 0 // 0..100
    property int temp: 0
    property bool showTemp: false
    property color accentColor: AppTheme.accent

    Layout.fillWidth: true
    spacing: AppTheme.paddingSmall

    onAccentColorChanged: canvas.requestPaint()

    Item {
        id: gaugeWrap
        Layout.alignment: Qt.AlignHCenter
        width: 128
        height: 128

        // Valor mostrado animado: los updates del servicio (1 Hz con popup
        // abierto) se ven fluidos y el Canvas solo repinta durante la
        // transición (~600 ms), no de continuo.
        property real displayedUsage: root.usage

        Behavior on displayedUsage {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }

        onDisplayedUsageChanged: canvas.requestPaint()

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.lineWidth = 10
                ctx.lineCap = "round"

                const cx = width / 2
                const cy = height / 2
                const r = Math.min(width, height) / 2 - ctx.lineWidth
                const start = Math.PI * 0.75
                const sweep = Math.PI * 1.5

                // Track
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + sweep)
                ctx.strokeStyle = Qt.alpha(AppTheme.fg, 0.12)
                ctx.stroke()

                // Progreso
                const frac = Math.max(0, Math.min(1, gaugeWrap.displayedUsage / 100))
                if (frac > 0.005) {
                    const grad = ctx.createLinearGradient(0, height, width, 0)
                    grad.addColorStop(0, root.accentColor)
                    grad.addColorStop(1, Qt.lighter(root.accentColor, 1.35))
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, start, start + sweep * frac)
                    ctx.strokeStyle = grad
                    ctx.stroke()
                }
            }

            Component.onCompleted: requestPaint()
        }

        Text {
            anchors.centerIn: parent
            text: Math.round(gaugeWrap.displayedUsage) + "%"
            font.family: AppTheme.fontLayout
            font.pixelSize: 26
            font.weight: Font.Bold
            color: AppTheme.fg
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.title
        font.family: AppTheme.fontLayout
        font.pixelSize: AppTheme.fontTiny
        font.weight: Font.Bold
        font.letterSpacing: 1.5
        color: AppTheme.textSecondary
    }

    Rectangle {
        visible: root.showTemp
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: tempText.implicitWidth + 16
        implicitHeight: 22
        radius: height / 2
        color: Qt.alpha(root.accentColor, 0.15)
        border.width: 1
        border.color: Qt.alpha(root.accentColor, 0.35)

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

        Text {
            id: tempText
            anchors.centerIn: parent
            text: root.temp + "°C"
            font.family: AppTheme.fontMono
            font.pixelSize: AppTheme.fontSmall
            font.weight: Font.Bold
            color: root.accentColor

            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }
}
