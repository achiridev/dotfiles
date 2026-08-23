// widgets/battery/BatteryPanel.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell._Window
import qs.services
import qs.globals

// Panel de batería: ventana REAL (xdg toplevel) flotante que Hyprland gestiona
// como cualquier otra: se abre centrada (regla "qs-battery-panel"), se mueve
// con Super+drag y convive normalmente con el resto de ventanas (la terminal
// de battery-mode abre encima). Se abre por click en el módulo de la barra y
// SOLO se cierra con su botón ✕. Muestra % grande, tiempo restante, barra de
// carga animada, potencia/salud/energía y selector de los 4 modos del script
// ~/.local/bin/battery-mode.
FloatingWindow {
    id: panel

    // ============================ SUB-COMPONENTES ============================
    component StatTile: Rectangle {
        id: tile
        property string label: ""
        property string value: ""
        property string sub: ""
        property color accent: AppTheme.accent

        Layout.fillWidth: true
        implicitHeight: tileCol.implicitHeight + AppTheme.paddingBase * 2
        radius: AppTheme.radiusSmall
        color: Qt.alpha(AppTheme.fg, 0.04)
        border.width: 1
        border.color: Qt.alpha(AppTheme.fg, 0.06)

        ColumnLayout {
            id: tileCol
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: 2

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: tile.label
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: AppTheme.textSecondary
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: tile.value
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontLarge
                font.weight: Font.Bold
                color: tile.accent

                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: tile.sub !== ""
                text: tile.sub
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                color: AppTheme.textTertiary
            }
        }
    }

    component ModeButton: Rectangle {
        id: btn
        property string mode: ""
        property string icon: ""
        property string title: ""
        property string desc: ""

        readonly property bool isActive: BatteryService.activeMode === mode

        Layout.fillWidth: true
        implicitHeight: btnRow.implicitHeight + AppTheme.paddingLarge * 2
        radius: AppTheme.radiusSmall
        color: isActive ? Qt.alpha(AppTheme.accent, 0.16)
             : mouse.containsMouse ? AppTheme.surface
             : Qt.alpha(AppTheme.fg, 0.03)
        border.width: 1
        border.color: isActive ? Qt.alpha(AppTheme.accent, 0.55) : Qt.alpha(AppTheme.fg, 0.08)

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: btnRow
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: AppTheme.paddingBase

            Text {
                text: btn.icon
                font.family: AppTheme.fontMono
                font.pixelSize: 24
                color: btn.isActive ? AppTheme.accent : AppTheme.textSecondary

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: btn.title
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontBase
                    font.weight: Font.Bold
                    color: btn.isActive ? AppTheme.accent : AppTheme.fg

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Text {
                    text: btn.desc
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textTertiary
                }
            }

            Text {
                visible: btn.isActive
                text: String.fromCodePoint(0xf00c) // ✓ check
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: AppTheme.accent
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: BatteryService.applyMode(btn.mode)
        }
    }

    component StatusPill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property string value: ""
        property color c: AppTheme.accent

        implicitWidth: pillRow.implicitWidth + 22
        implicitHeight: 30
        radius: height / 2
        color: Qt.alpha(c, 0.10)
        border.width: 1
        border.color: Qt.alpha(c, 0.28)

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                text: pill.icon
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                color: pill.c

                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Text {
                text: pill.label
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                color: AppTheme.textSecondary
            }

            Text {
                text: pill.value
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: pill.c

                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    // ================================ ESTADO =================================
    // Lo maneja el padre (click en el módulo). La ventana se oculta con
    // `shown` para poder reproducir la animación de salida.
    property bool requestOpen: false
    property bool shown: false
    signal closeRequested()

    readonly property int cardWidth: 700

    readonly property bool charging: BatteryService.isCharging
    readonly property color levelColor: charging ? BatteryService.colorCharning : BatteryService.levelColor(BatteryService.percentage)

    // Identificador para la windowrule de Hyprland (float + center).
    title: "qs-battery-panel"

    visible: shown
    color: "transparent"

    implicitWidth: cardWidth
    implicitHeight: layout.implicitHeight + (AppTheme.paddingLarge + AppTheme.paddingBase) * 2

    onRequestOpenChanged: {
        if (requestOpen) {
            closeAnim.stop()
            if (!shown) {
                shown = true // onShownChanged lanza la animación de apertura
            } else {
                // Reabierta a mitad del cierre: reinicia y vuelve a abrir.
                __resetCard()
                openAnim.start()
            }
        } else if (shown && !closeAnim.running) {
            closeAnim.start()
        }
    }

    onShownChanged: {
        if (shown) {
            __resetCard()
            openAnim.start()
        }
    }

    function __resetCard() {
        card.opacity = 0
        card.scale = 0.92
        card.y = 10
    }

    Rectangle {
        id: card
        width: panel.width
        height: panel.height
        radius: AppTheme.radiusLarge
        color: AppTheme.bgPopup
        border.width: 1
        border.color: AppTheme.borderColor
        transformOrigin: Item.Center

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: AppTheme.paddingLarge + AppTheme.paddingBase
            spacing: AppTheme.paddingLarge

            // ============================= HEADER ============================
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingBase

                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46
                    radius: AppTheme.radiusSmall
                    color: Qt.alpha(panel.levelColor, 0.14)
                    border.width: 1
                    border.color: Qt.alpha(panel.levelColor, 0.32)

                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    Text {
                        anchors.centerIn: parent
                        text: BatteryService.batteryIcon
                        font.family: AppTheme.fontMono
                        font.pixelSize: 26
                        color: panel.levelColor

                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: "BATERÍA"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontLarge
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                        color: AppTheme.fg
                    }

                    Text {
                        Layout.fillWidth: true
                        text: BatteryService.batteryInfo.model || BatteryService.batteryInfo.vendor || "Batería interna"
                        elide: Text.ElideRight
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        color: AppTheme.textSecondary
                    }
                }

                Rectangle {
                    id: closeButton
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: AppTheme.radiusSmall
                    color: closeMa.containsMouse ? AppTheme.surface : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        font.weight: Font.Bold
                        color: closeMa.containsMouse ? AppTheme.fg : AppTheme.textSecondary
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.closeRequested()
                    }
                }
            }

            // ============================== HERO =============================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: heroRow.implicitHeight + AppTheme.paddingLarge * 2
                radius: AppTheme.radius
                color: Qt.alpha(AppTheme.fg, 0.04)
                border.width: 1
                border.color: Qt.alpha(AppTheme.fg, 0.06)

                RowLayout {
                    id: heroRow
                    anchors.fill: parent
                    anchors.margins: AppTheme.paddingLarge
                    spacing: AppTheme.paddingLarge

                    Text {
                        text: BatteryService.percentage + "%"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: 56
                        font.weight: Font.Bold
                        color: panel.levelColor

                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: BatteryService.statusText
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                            color: panel.levelColor

                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        RowLayout {
                            spacing: 6

                            Text {
                                text: String.fromCodePoint(0xf0954) // reloj
                                font.family: AppTheme.fontMono
                                font.pixelSize: AppTheme.fontBase
                                color: AppTheme.textSecondary
                            }

                            Text {
                                text: {
                                    if (BatteryService.isFull) return "Carga completa"
                                    const t = BatteryService.timeRemainingText
                                    if (t === "—") return "Calculando…"
                                    return t + (BatteryService.isCharging ? " para completar" : " restantes")
                                }
                                font.family: AppTheme.fontMono
                                font.pixelSize: AppTheme.fontLarge
                                font.weight: Font.Bold
                                color: AppTheme.fg
                            }
                        }
                    }

                    Text {
                        text: BatteryService.batteryIcon
                        font.family: AppTheme.fontMono
                        font.pixelSize: 44
                        color: panel.levelColor

                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }

            // ========================== BARRA DE CARGA =======================
            Rectangle {
                id: chargeTrack
                Layout.fillWidth: true
                implicitHeight: 14
                radius: height / 2
                color: Qt.alpha(AppTheme.fg, 0.10)

                readonly property real fraction: Math.max(0, Math.min(1, BatteryService.percentage / 100))

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        margins: 2
                    }
                    radius: height / 2
                    width: (chargeTrack.width - 4) * chargeTrack.fraction

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: panel.levelColor }
                        GradientStop { position: 1; color: Qt.lighter(panel.levelColor, 1.3) }
                    }

                    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    // Pulso sutil solo mientras carga (y el panel está visible).
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "#ffffff"
                        opacity: 0

                        SequentialAnimation on opacity {
                            running: panel.shown && BatteryService.isCharging
                            loops: Animation.Infinite

                            NumberAnimation { to: 0.22; duration: 700; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 0.04; duration: 700; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }

            // ============================== STATS ============================
            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                StatTile {
                    label: "POTENCIA"
                    value: BatteryService.formatPower()
                    sub: BatteryService.charging ? "entrando" : "consumiéndose"
                    accent: panel.levelColor
                }

                StatTile {
                    label: "SALUD"
                    value: BatteryService.healthSupported ? BatteryService.healthPercent + "%" : "—"
                    sub: BatteryService.healthSupported ? "vs capacidad de diseño" : "no disponible"
                    accent: !BatteryService.healthSupported ? AppTheme.color8
                          : BatteryService.healthPercent >= 80 ? AppTheme.success
                          : BatteryService.healthPercent >= 50 ? AppTheme.warning
                          : AppTheme.critical
                }

                StatTile {
                    label: "ENERGÍA"
                    value: BatteryService.formatEnergy()
                    sub: "restante / total"
                    accent: AppTheme.accent
                }
            }

            // ============================ DIVISOR ============================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            // ========================= MODOS DE ENERGÍA ======================
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "MODO DE ENERGÍA"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: AppTheme.textSecondary
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "requiere sudo"
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textTertiary
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: AppTheme.paddingSmall
                rowSpacing: AppTheme.paddingSmall

                ModeButton {
                    mode: "off"
                    icon: String.fromCodePoint(0xf0082)
                    title: "Normal"
                    desc: "GPU híbrida · CPU auto"
                }

                ModeButton {
                    mode: "low"
                    icon: String.fromCodePoint(0xf007b)
                    title: "Ahorro"
                    desc: "powersave · turbo off"
                }

                ModeButton {
                    mode: "high"
                    icon: String.fromCodePoint(0xf186) // luna
                    title: "Ahorro máx."
                    desc: "solo iGPU · BT off · dpms"
                }

                ModeButton {
                    mode: "gaming"
                    icon: String.fromCodePoint(0xf0e7) // rayo
                    title: "Gaming"
                    desc: "GPU dedicada · performance"
                }
            }

            // ============================ DIVISOR ============================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            // ======================== ESTADO DEL SISTEMA =====================
            Flow {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                StatusPill {
                    icon: String.fromCodePoint(0xf1119) // chip
                    label: "GPU"
                    value: BatteryService.gpuMode || "?"
                    c: BatteryService.gpuMode === "integrated" ? AppTheme.success
                     : BatteryService.gpuMode === "nvidia" ? AppTheme.warning
                     : BatteryService.gpuMode === "" ? AppTheme.color8
                     : AppTheme.accent
                }

                StatusPill {
                    icon: String.fromCodePoint(0xf2db) // microchip
                    label: "CPU"
                    value: (BatteryService.governor || "?") + (BatteryService.turboEnabled ? " · boost ON" : " · boost OFF")
                    c: BatteryService.governor === "performance" ? AppTheme.warning
                     : BatteryService.governor === "powersave" ? AppTheme.success
                     : AppTheme.accent
                }

                StatusPill {
                    icon: String.fromCodePoint(0xf013) // engranaje
                    label: "TLP"
                    value: BatteryService.tlpActive ? "activo" : "inactivo"
                    c: BatteryService.tlpActive ? AppTheme.success : AppTheme.critical
                }

                StatusPill {
                    icon: String.fromCodePoint(0xf013)
                    label: "CPUFREQ"
                    value: BatteryService.cpufreqActive ? "activo" : "inactivo"
                    c: BatteryService.cpufreqActive ? AppTheme.success : AppTheme.critical
                }
            }
        }
    }

    // Apertura: fade + escala + slide sutil hacia el centro.
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "y"; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }

    // Cierre: se oculta la ventana recién cuando termina la animación.
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "scale"; to: 0.95; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "y"; to: 6; duration: 140; easing.type: Easing.InCubic }
        onFinished: panel.shown = false
    }
}
