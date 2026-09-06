// widgets/control/ColorSection.qml
// Sección "Colores" del Panel de Control.
// - Selector de temas built-in de Wallust (Catppuccin, Nord, Gruvbox...).
// - Ajuste fino del color de acento en runtime (solo UI Quickshell).
// - Preview en vivo de la paleta activa (generada por wallust).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.globals

Item {
    id: root

    // Altura natural de la sección (para que el panel se ajuste).
    readonly property int sectionHeight: 430

    readonly property string wallustDir: Quickshell.env("HOME") + "/dotfiles/config/wallust/.config/wallust"

    // Temas destacados de Wallust para mostrar como botones.
    readonly property var themes: [
        "Catppuccin-Mocha",
        "Catppuccin-Macchiato",
        "Nord",
        "Gruvbox-Dark",
        "Rosé-Pine",
        "Tokyo-Night",
        "Dracula",
        "One-Dark"
    ]

    // Paleta actual (reactiva desde AppTheme).
    readonly property var pal: AppTheme.colors

    function palValue(section, key, fallback) {
        if (!root.pal || !root.pal[section]) return fallback
        var v = root.pal[section][key]
        return v ? v : fallback
    }

    // Estado: tema en aplicación / listo.
    property bool applying: false
    property string lastTheme: ""

    // Aplica un tema built-in de Wallust y recarga apps/teclado.
    function applyTheme(name) {
        if (root.applying) return
        root.lastTheme = name
        root.applying = true
        root.resetAccent()
        themeProcess.command = [
            "sh", "-c",
            "wallust --config-dir \"" + root.wallustDir + "\" --skip-sequences theme \"" + name + "\" >/dev/null 2>&1 && " +
            "\"" + Quickshell.env("HOME") + "/dotfiles/bin/.local/bin/wallust-keyboard.sh\" >/dev/null 2>&1; " +
            "kitty @ set-colors -a ~/.config/kitty/colors.conf 2>/dev/null || true; " +
            "hyprctl reload 2>/dev/null || true; " +
            "pkill -SIGUSR2 swaync 2>/dev/null || true; pkill rofi 2>/dev/null || true; true"
        ]
        themeProcess.running = true
    }

    Process {
        id: themeProcess
        onExited: root.applying = false
    }

    // ============================ SUB-COMPONENTES ============================
    component SectionLabel: Text {
        color: AppTheme.textSecondary
        font.family: AppTheme.fontLayout
        font.pixelSize: AppTheme.fontSmall
        font.weight: Font.Bold
        font.letterSpacing: 1.5
    }

    component ActionButton: Rectangle {
        id: btn
        property string text: ""
        property string icon: ""
        property bool highlighted: false

        implicitHeight: btnRow.implicitHeight + AppTheme.paddingBase * 2
        Layout.fillWidth: false
        radius: AppTheme.radiusSmall
        color: highlighted ? Qt.alpha(AppTheme.accent, 0.18)
             : ma.containsMouse ? AppTheme.surface
             : Qt.alpha(AppTheme.fg, 0.03)
        border.width: 1
        border.color: highlighted ? Qt.alpha(AppTheme.accent, 0.55) : Qt.alpha(AppTheme.fg, 0.08)

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: btnRow
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: AppTheme.paddingSmall

            Text {
                text: btn.icon
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                color: highlighted ? AppTheme.accent : AppTheme.textSecondary
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Text {
                text: btn.text
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: highlighted ? AppTheme.accent : AppTheme.fg
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }

        signal clicked()
    }

    component ThemeChip: Rectangle {
        id: chip
        property string name: ""
        property bool active: false

        implicitHeight: chipRow.implicitHeight + AppTheme.paddingBase * 2
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        radius: AppTheme.radiusSmall
        color: active ? Qt.alpha(AppTheme.accent, 0.18)
             : ma.containsMouse ? AppTheme.surface
             : Qt.alpha(AppTheme.fg, 0.03)
        border.width: 1
        border.color: active ? Qt.alpha(AppTheme.accent, 0.55) : Qt.alpha(AppTheme.fg, 0.08)

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: chipRow
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: AppTheme.paddingSmall

            Text {
                text: String.fromCodePoint(0xf1fc) // pincel (temas)
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                color: active ? AppTheme.accent : AppTheme.textSecondary
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                Layout.fillWidth: true
                text: chip.name
                elide: Text.ElideRight
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: active ? AppTheme.accent : AppTheme.fg
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                visible: chip.active || (root.applying && root.lastTheme === chip.name)
                text: root.applying && root.lastTheme === chip.name ? String.fromCodePoint(0xf021)
                     : String.fromCodePoint(0xf00c)
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: AppTheme.accent

                RotationAnimation on rotation {
                    running: root.applying && root.lastTheme === chip.name
                    from: 0; to: 360
                    duration: 800; loops: Animation.Infinite
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyTheme(chip.name)
        }
    }

    component Swatch: Rectangle {
        property string hex: "#000"
        Layout.fillWidth: true
        Layout.preferredHeight: 22
        radius: AppTheme.radiusSmall
        color: hex
        border.width: 1
        border.color: Qt.alpha(AppTheme.fg, 0.15)
    }

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: root.width
            spacing: AppTheme.paddingBase

            // ========================== TEMAS ===========================
            SectionLabel { text: "TEMAS WALLUST" }

            Flow {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                Repeater {
                    model: root.themes
                    delegate: Item {
                        width: (parent.width - AppTheme.paddingSmall) / 2
                        height: 40
                        ThemeChip {
                            anchors.fill: parent
                            name: modelData
                            active: !root.applying && root.lastTheme === modelData
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            // ======================== ACENTO FINO ========================
            RowLayout {
                Layout.fillWidth: true

                SectionLabel { text: "ACENTO" }

                Item { Layout.fillWidth: true }

                Text {
                    text: AppTheme.accent.toString()
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textSecondary
                }

                Rectangle {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: AppTheme.radiusSmall
                    color: AppTheme.accent
                    border.width: 1
                    border.color: Qt.alpha(AppTheme.fg, 0.3)
                }
            }

            // Barra de matiz continua (0-360).
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: height / 2
                border.width: 1
                border.color: Qt.alpha(AppTheme.fg, 0.12)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.00; color: "#ff0000" }
                        GradientStop { position: 0.17; color: "#ffff00" }
                        GradientStop { position: 0.33; color: "#00ff00" }
                        GradientStop { position: 0.50; color: "#00ffff" }
                        GradientStop { position: 0.67; color: "#0000ff" }
                        GradientStop { position: 0.83; color: "#ff00ff" }
                        GradientStop { position: 1.00; color: "#ff0000" }
                    }
                }

                Rectangle {
                    y: (parent.height - 20) / 2
                    x: Math.max(3, Math.min(parent.width - 23, (root.accentHue / 360) * (parent.width - 26) + 3))
                    width: 20
                    height: 20
                    radius: 10
                    color: "#ffffff"
                    border.width: 2
                    border.color: AppTheme.fg
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setAccentHueFromX(mouse.x, parent.width)
                    onPositionChanged: if (pressed) root.setAccentHueFromX(mouse.x, parent.width)
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                ActionButton {
                    id: resetBtn
                    text: "Restablecer"
                    icon: String.fromCodePoint(0xf0e2) // flecha circular
                    highlighted: true
                    onClicked: root.resetAccent()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            // ==================== PREVIEW DE PALETA =====================
            SectionLabel { text: "PALETA ACTIVA" }

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall
                Swatch { hex: root.palValue("special", "background", "#111") }
                Swatch { hex: root.palValue("special", "foreground", "#fff") }
                Swatch { hex: root.palValue("special", "cursor", "#fff") }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall
                Repeater { model: 8; delegate: Swatch { hex: root.colorAtIndex(index) } }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall
                Repeater { model: 8; delegate: Swatch { hex: root.colorAtIndex(index + 8) } }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ============================ HELPERS ============================
    function colorAtIndex(i) {
        if (!root.pal || !root.pal.colors) return "#555"
        var c = root.pal.colors["color" + i]
        return c ? c : "#555"
    }

    function hueOf(c) {
        var r = c.r, g = c.g, b = c.b
        var max = Math.max(r, g, b), min = Math.min(r, g, b)
        var h = 0
        if (max !== min) {
            var d = max - min
            if (max === r) h = ((g - b) / d + (g < b ? 6 : 0))
            else if (max === g) h = (b - r) / d + 2
            else h = (r - g) / d + 4
            h *= 60
        }
        return h
    }

    // Matiz base del acento de la paleta (color5).
    readonly property int baseAccentHue: Math.round(root.hueOf(AppTheme.color5))
    property int accentHue: baseAccentHue

    onBaseAccentHueChanged: root.accentHue = root.baseAccentHue

    function setAccentHueFromX(x, width) {
        var h = Math.max(0, Math.min(360, (x / width) * 360))
        root.accentHue = h
        // Mantener saturación/luminosidad del acento base para que se vea bien.
        AppTheme.accentOverride = Qt.hsla(h / 360, 0.85, 0.66, 1)
    }
    function resetAccent() {
        root.accentHue = root.baseAccentHue
        AppTheme.accentOverride = "transparent"
    }
}