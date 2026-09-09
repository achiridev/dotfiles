// widgets/control/ColorSection.qml
// Sección "Colores" del Panel de Control.
// - Selector de temas built-in de Wallust (Catppuccin, Nord, Gruvbox...).
// - Ajuste fino del color de acento en runtime (solo UI Quickshell).
// - Editor de la paleta activa: muestra los colores de Wallust y permite
//   modificarlos uno por uno re-renderizando templates con `wallust cs`.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.globals

Item {
    id: root

    // Altura natural de la sección (para que el panel se ajuste).
    readonly property int sectionHeight: 760

    readonly property string wallustDir: Quickshell.env("HOME") + "/dotfiles/config/wallust/.config/wallust"
    readonly property string schemeDir: root.wallustDir + "/colorschemes"
    readonly property string schemeFile: root.schemeDir + "/custom.json"

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

    // =====================================================================
    // Editor de colores activos
    // =====================================================================

    // Entradas editables: [etiqueta, sección, clave].
    readonly property var editableSpec: [
        ["bg",  "special", "background"],
        ["fg",  "special", "foreground"],
        ["cursor", "special", "cursor"],
        ["c0",  "colors", "color0"],  ["c1",  "colors", "color1"],
        ["c2",  "colors", "color2"],  ["c3",  "colors", "color3"],
        ["c4",  "colors", "color4"],  ["c5",  "colors", "color5"],
        ["c6",  "colors", "color6"],  ["c7",  "colors", "color7"],
        ["c8",  "colors", "color8"],  ["c9",  "colors", "color9"],
        ["c10", "colors", "color10"], ["c11", "colors", "color11"],
        ["c12", "colors", "color12"], ["c13", "colors", "color13"],
        ["c14", "colors", "color14"], ["c15", "colors", "color15"]
    ]

    // Hex actual por índice (inicializado desde la paleta activa).
    property var customHex: (function () {
        var out = []
        for (var i = 0; i < root.editableSpec.length; i++) {
            var spec = root.editableSpec[i]
            var v = root.palValue(spec[1], spec[2], i < 3 ? (i === 0 ? "#111111" : "#eeeeee") : "#555555")
            out.push(root.colorToHex(v))
        }
        return out
    })()

    // Cuando cambia la paleta externamente (tema/aplicado), resincronizar entradas.
    signal paletteSynced()
    onPaletteSynced: {
        for (var i = 0; i < root.editableSpec.length; i++) {
            var spec = root.editableSpec[i]
            var v = root.palValue(spec[1], spec[2], "")
            if (v) root.customHex[i] = root.colorToHex(v)
        }
    }

    function colorToHex(c) {
        if (!c) return "#555555"
        var s = c.toString()
        if (s.length >= 7) return s.slice(0, 7)
        return "#555555"
    }

    // Hex valido => color (para el swatch); inválido => gris.
    function hexValid(hex) {
        return /^#[0-9a-fA-F]{6}$/.test(hex)
    }
    function hexColor(hex) {
        return root.hexValid(hex) ? hex : "#555555"
    }
    readonly property bool allValid: (function () {
        for (var i = 0; i < root.customHex.length; i++) {
            if (!root.hexValid(root.customHex[i])) return false
        }
        return true
    })()

    property bool customDirty: false

    // Estado: tema en aplicación / listo.
    property bool applying: false
    property string lastTheme: ""
    property bool applyingCustom: false
    property bool customActive: false

    // Aplica un tema built-in de Wallust y recarga apps/teclado.
    function applyTheme(name) {
        if (root.applying) return
        root.lastTheme = name
        root.customActive = false
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
        onExited: {
            root.applying = false
            root.paletteSynced()
        }
    }

    // Serializa los hex editados al formato de colorscheme de wallust (cache).
    function buildSchemeJson() {
        var special = {
            "background": root.customHex[0],
            "foreground": root.customHex[1],
            "cursor": root.customHex[2]
        }
        var colors = {}
        for (var i = 3; i < root.editableSpec.length; i++) {
            colors["color" + (i - 3)] = root.customHex[i]
        }
        return JSON.stringify({ "special": special, "colors": colors })
    }

    // Escribe colorschemes/custom.json y re-renderiza con `wallust cs custom`.
    function applyCustom() {
        if (root.applying || root.applyingCustom) return
        if (!root.allValid) return
        root.applyingCustom = true
        root.customActive = true
        customApplyProcess.environment = { WALLUST_JSON: root.buildSchemeJson() }
        customApplyProcess.command = [
            "sh", "-c",
            "mkdir -p \"" + root.schemeDir + "\" &&
             printf '%s' \"$WALLUST_JSON\" > \"" + root.schemeFile + "\" &&
             wallust --config-dir \"" + root.wallustDir + "\" --skip-sequences cs custom >/dev/null 2>&1 &&
             \"" + Quickshell.env("HOME") + "/dotfiles/bin/.local/bin/wallust-keyboard.sh\" >/dev/null 2>&1; " +
            "kitty @ set-colors -a ~/.config/kitty/colors.conf 2>/dev/null || true; " +
            "hyprctl reload 2>/dev/null || true; " +
            "pkill -SIGUSR2 swaync 2>/dev/null || true; pkill rofi 2>/dev/null || true; true"
        ]
        customApplyProcess.running = true
    }

    Process {
        id: customApplyProcess
        onExited: {
            root.applyingCustom = false
            root.customDirty = false
            root.paletteSynced()
        }
    }

    // Borra el esquema custom y vuelve al último tema de la grilla.
    function resetCustom() {
        if (root.applying || root.applyingCustom) return
        root.applyingCustom = true
        root.customActive = false
        root.customDirty = false
        resetProcess.command = [
            "sh", "-c",
            "rm -f \"" + root.schemeFile + "\"; " +
            "if [ -n \"" + root.lastTheme + "\" ]; then " +
            "wallust --config-dir \"" + root.wallustDir + "\" --skip-sequences theme \"" + root.lastTheme + "\" >/dev/null 2>&1; " +
            "else " +
            "\"" + Quickshell.env("HOME") + "/dotfiles/bin/.local/bin/wallust-keyboard.sh\" >/dev/null 2>&1; " +
            "fi; true"
        ]
        resetProcess.running = true
    }

    Process {
        id: resetProcess
        onExited: {
            root.applyingCustom = false
            root.paletteSynced()
        }
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
        property bool enabled: true
        property bool busy: false

        implicitHeight: btnRow.implicitHeight + AppTheme.paddingBase * 2
        Layout.fillWidth: false
        radius: AppTheme.radiusSmall
        opacity: btn.enabled ? 1 : 0.5
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
                visible: !btn.busy
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
            Text {
                visible: btn.busy
                text: String.fromCodePoint(0xf021)
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                color: AppTheme.accent
                RotationAnimation on rotation {
                    running: btn.busy
                    from: 0; to: 360
                    duration: 800; loops: Animation.Infinite
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            enabled: btn.enabled
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

    // Celda editable de la grilla de colores activos.
    component ColorCell: Rectangle {
        id: cell
        property int colorIndex: -1

        implicitHeight: Math.max(AppTheme.paddingBase * 2 + tf.implicitHeight, 34)
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        radius: AppTheme.radiusSmall
        color: cellStyle.hovered ? AppTheme.surface : Qt.alpha(AppTheme.fg, 0.03)
        border.width: 1
        border.color: cellStyle.hovered || cell.fieldActive ? Qt.alpha(AppTheme.accent, 0.45)
                    : Qt.alpha(AppTheme.fg, 0.08)
        clip: true

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: AppTheme.paddingSmall

            Text {
                Layout.preferredWidth: cellCellLabelW
                property int cellCellLabelW: root.editableSpec[cell.colorIndex] && root.editableSpec[cell.colorIndex][0].length > 2 ? 34 : 20
                text: root.editableSpec[cell.colorIndex] ? root.editableSpec[cell.colorIndex][0] : ""
                horizontalAlignment: Text.AlignHCenter
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                font.weight: Font.Bold
                color: AppTheme.textSecondary
            }

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: AppTheme.radiusSmall
                color: root.hexColor(root.customHex[cell.colorIndex])
                border.width: 1
                border.color: Qt.alpha(AppTheme.fg, 0.3)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tf.forceActiveFocus()
                }
            }

            TextField {
                id: tf
                Layout.fillWidth: true
                property bool fieldActive: false
                text: root.customHex[cell.colorIndex]
                selectByMouse: true
                validator: RegularExpressionValidator {
                    regularExpression: /(^$)|(^#[0-9a-fA-F]{6}$)/
                }
                onTextEdited: {
                    root.customHex[cell.colorIndex] = tf.text
                    root.customDirty = true
                }
                onActiveFocusChanged: tf.fieldActive = tf.activeFocus
                onAccepted: root.customHex[cell.colorIndex] = tf.text.length === 7 ? tf.text : (tf.text.length === 6 ? "#" + tf.text : tf.text)

                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                color: root.hexValid(tf.text) ? AppTheme.fg : AppTheme.critical
                background: Rectangle {
                    radius: AppTheme.radiusSmall
                    color: Qt.alpha(AppTheme.fg, 0.06)
                    border.width: 1
                    border.color: tf.fieldActive ? Qt.alpha(root.accent, 0.5) : Qt.alpha(AppTheme.fg, 0.1)
                }
            }
        }

        MouseArea {
            id: cellStyle
            property bool hovered: false
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tf.forceActiveFocus()
            onEntered: cellStyle.hovered = true
            onExited: cellStyle.hovered = false
            z: -1
        }
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
                            active: !root.customActive && !root.applying && root.lastTheme === modelData
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

            // ==================== COLORES ACTIVOS ========================
            RowLayout {
                Layout.fillWidth: true

                SectionLabel { text: "COLORES ACTIVOS" }

                Item { Layout.fillWidth: true }

                Text {
                    visible: root.customDirty
                    text: String.fromCodePoint(0xf05a) // info
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.warning
                }
            }

            // Grilla 2 columnas: bg/fg/cursor + color0..15.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingSmall
                    ColorCell { colorIndex: 0 }
                    ColorCell { colorIndex: 1 }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingSmall
                    ColorCell { colorIndex: 2 }
                    Item { Layout.fillWidth: true; Layout.preferredHeight: 34 }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingSmall
                    Repeater { model: 4; delegate: ColorCell { colorIndex: 3 + index } }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingSmall
                    Repeater { model: 4; delegate: ColorCell { colorIndex: 7 + index } }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingSmall
                    Repeater { model: 4; delegate: ColorCell { colorIndex: 11 + index } }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingSmall
                    Repeater { model: 4; delegate: ColorCell { colorIndex: 15 + index } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                Item { Layout.fillWidth: true }

                ActionButton {
                    id: applyCustomBtn
                    text: root.customDirty ? "Aplicar colores" : "Aplicar"
                    icon: String.fromCodePoint(0xf00c) // check
                    highlighted: !root.customDirty
                    enabled: root.allValid && !root.applying && !root.applyingCustom
                    busy: root.applyingCustom
                    onClicked: root.applyCustom()
                }

                ActionButton {
                    id: resetCustomBtn
                    text: "Del wallpaper"
                    icon: String.fromCodePoint(0xf0e2) // flecha circular
                    enabled: !root.applying && !root.applyingCustom
                    busy: false
                    onClicked: root.resetCustom()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: root.width
                wrapMode: Text.WordWrap
                text: "Los cambios se guardan en colorschemes/custom.json y se re-renderizan con wallust cs."
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                color: AppTheme.textTertiary
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