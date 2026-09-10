// widgets/control/ColorSection.qml
// Sección "Colores" del Panel de Control.
// - Selector de temas built-in de Wallust (Catppuccin, Nord, Gruvbox...).
// - Ajuste fino del color de acento en runtime (solo UI Quickshell).
// - Barra de matiz compartida: hace click en un color de la grilla para
//   seleccionarlo y la barra cambia su color (persistido con "Aplicar").
// - Historial de "Deshacer" para revertir las últimas ediciones de paleta.
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
    readonly property int sectionHeight: 950

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
        // El preview en vivo ya no aplica: colors.json refleja el estado.
        AppTheme.clearPalettePreview()
        root.selectedColorIndex = -1
        root.editSequenceActive = false
        var resynced = root.customHex.slice()
        for (var i = 0; i < root.editableSpec.length; i++) {
            var spec = root.editableSpec[i]
            var v = root.palValue(spec[1], spec[2], "")
            if (v) resynced[i] = root.colorToHex(v)
        }
        // Reasignar el array entero para que los bindings (swatches, barra,
        // allValid) se reevalúen: QML no notifica mutaciones in-place de var.
        // NOTA: NO se borra undoStack aquí: el "Deshacer" debe seguir
        // funcionando tras aplicar. Solo applyTheme()/resetCustom() abren una
        // base nueva.
        root.customHex = resynced
        root.syncAccentSl()
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

    // Selección del color de paleta editado por la barra (-1 = modo acento).
    property int selectedColorIndex: -1
    property real selectSat: 0.85
    property real selectLight: 0.66

    // Historial de "Deshacer": snapshots de customHex previos a cada edición.
    property var undoStack: []
    property bool editSequenceActive: false
    readonly property bool canUndo: root.undoStack.length > 0

    // Estado: tema en aplicación / listo.
    property bool applying: false
    property string lastTheme: ""
    property bool applyingCustom: false
    property bool customActive: false
    // Resultado del último proceso de aplicación ("" = sin estado).
    property string applyStatus: ""

    // Aplica un tema built-in de Wallust y recarga apps/teclado.
    function applyTheme(name) {
        if (root.applying) return
        root.lastTheme = name
        root.selectedColorIndex = -1
        root.undoStack = []
        root.editSequenceActive = false
        root.customActive = false
        root.applyStatus = ""
        root.applying = true
        root.resetAccent()
        themeProcess.command = [
            "sh", "-c",
            "CS_OK=0; " +
            "wallust --config-dir \"" + root.wallustDir + "\" --skip-sequences theme \"" + name + "\" >>\"" + Quickshell.env("HOME") + "/.cache/wallust-apply.log\" 2>&1 || CS_OK=1; " +
            "\"" + Quickshell.env("HOME") + "/dotfiles/bin/.local/bin/wallust-keyboard.sh\" >/dev/null 2>&1; " +
            "kitty @ set-colors -a ~/.config/kitty/colors.conf 2>/dev/null || true; " +
            "hyprctl reload 2>/dev/null || true; " +
            "pkill -SIGUSR2 swaync 2>/dev/null || true; pkill rofi 2>/dev/null || true; " +
            "exit $CS_OK"
        ]
        themeProcess.running = true
    }

    Process {
        id: themeProcess
        onExited: (exitCode) => {
            root.applying = false
            root.applyStatus = exitCode === 0 ? "OK" : "ERROR"
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
    // `fromUndo`: el aplicar lo dispara Deshacer (no empuja otro snapshot).
    function applyCustom(fromUndo) {
        if (root.applying || root.applyingCustom) return
        if (!root.allValid) return
        if (!fromUndo) {
            // El undo debe poder revertir el cambio YA aplicado: el snapshot a
            // mantener es el previo a esta operación. No apilamos otro igual.
            var top = root.undoStack[root.undoStack.length - 1]
            if (top && top.type === "accent") {
                // El acento se plasmará en color5: el paso deshacible pasa a
                // ser restaurar la paleta previa al plegado.
                root.undoStack = root.undoStack.slice(0, root.undoStack.length - 1)
                    .concat([{ type: "palette", hex: root.customHex.slice() }])
                root.editSequenceActive = true
            } else if (!top) {
                root.undoStack = [{ type: "palette", hex: root.customHex.slice() }]
                root.editSequenceActive = true
            }
        }
        root.applyingCustom = true
        root.customActive = true
        root.applyStatus = ""
        // Persistir el acento en color5 (índice 3+5): las apps lo adoptan.
        if (AppTheme.accentOverride.a > 0) {
            var accHex = root.colorToHex(AppTheme.accentOverride)
            if (root.hexValid(accHex) && root.customHex[pIdx(5)] !== accHex) {
                root.setHex(pIdx(5), accHex)
                root.syncSelectHsl()
            }
        }
        customApplyProcess.environment = { WALLUST_JSON: root.buildSchemeJson() }
        customApplyProcess.command = [
            "sh", "-c",
            "CS_OK=0; " +
            "if ! mkdir -p \"" + root.schemeDir + "\" || ! printf '%s' \"$WALLUST_JSON\" > \"" + root.schemeFile + "\"; then " +
            "echo 'apply-custom: no se pudo escribir ' \"" + root.schemeFile + "\" >>\"" + Quickshell.env("HOME") + "/.cache/wallust-apply.log\"; exit 1; fi; " +
            "wallust --config-dir \"" + root.wallustDir + "\" --skip-sequences cs custom >/dev/null 2>>\"" + Quickshell.env("HOME") + "/.cache/wallust-apply.log\" || CS_OK=1; " +
            "\"" + Quickshell.env("HOME") + "/dotfiles/bin/.local/bin/wallust-keyboard.sh\" >/dev/null 2>&1; " +
            "kitty @ set-colors -a ~/.config/kitty/colors.conf 2>/dev/null || true; " +
            "hyprctl reload 2>/dev/null || true; " +
            "pkill -SIGUSR2 swaync 2>/dev/null || true; pkill rofi 2>/dev/null || true; " +
            "exit $CS_OK"
        ]
        customApplyProcess.running = true
    }

    Process {
        id: customApplyProcess
        onExited: (exitCode) => {
            root.applyingCustom = false
            root.customDirty = false
            root.applyStatus = exitCode === 0 ? "OK" : "ERROR"
            root.resetAccent()
            root.paletteSynced()
        }
    }

    // Borra el esquema custom y vuelve al último tema de la grilla.
    function resetCustom() {
        if (root.applying || root.applyingCustom) return
        root.applyingCustom = true
        root.customActive = false
        root.customDirty = false
        root.undoStack = []
        root.editSequenceActive = false
        root.applyStatus = ""
        resetProcess.command = [
            "sh", "-c",
            "CS_OK=0; rm -f \"" + root.schemeFile + "\"; " +
            "if [ -n \"" + root.lastTheme + "\" ]; then " +
            "wallust --config-dir \"" + root.wallustDir + "\" --skip-sequences theme \"" + root.lastTheme + "\" >>\"" + Quickshell.env("HOME") + "/.cache/wallust-apply.log\" 2>&1 || CS_OK=1; " +
            "else " +
            "\"" + Quickshell.env("HOME") + "/dotfiles/bin/.local/bin/wallust-keyboard.sh\" >/dev/null 2>&1; " +
            "fi; exit $CS_OK"
        ]
        resetProcess.running = true
    }

    Process {
        id: resetProcess
        onExited: (exitCode) => {
            root.applyingCustom = false
            root.applyStatus = exitCode === 0 ? "OK" : "ERROR"
            root.paletteSynced()
        }
    }

    // ================== SELECCIÓN DEL COLOR EDITADO ==================
    // La barra de matiz edita el color de paleta seleccionado (-1 = acento).
    function selectColor(index) {
        if (index === root.selectedColorIndex) {
            root.selectedColorIndex = -1
            root.syncAccentSl()
        } else {
            root.selectedColorIndex = index
            root.syncSelectHsl()
        }
        root.editSequenceActive = false
    }

    // Asegura que `index` quede seleccionado (sin toggle), para foco/teclado.
    function ensureColorSelected(index) {
        if (root.selectedColorIndex !== index) {
            root.selectedColorIndex = index
            root.syncSelectHsl()
            root.editSequenceActive = false
        }
    }

    // Recalcula saturación/luminosidad guardadas del color seleccionado.
    function syncSelectHsl() {
        if (root.selectedColorIndex < 0) return
        var hex = root.customHex[root.selectedColorIndex]
        if (!root.hexValid(hex)) return
        var hsl = root.hslFromHex(hex)
        root.selectSat = hsl.s
        root.selectLight = hsl.l
    }

    // Saturación/luminosidad actuales del acento (override o color5 base).
    function syncAccentSl() {
        var hex = root.colorToHex(AppTheme.accent)
        if (!root.hexValid(hex)) return
        var hsl = root.hslFromHex(hex)
        root.selectSat = hsl.s
        root.selectLight = hsl.l
    }

    // Actualiza un hex de la paleta REASIGNANDO el array completo: las
    // mutaciones in-place de un `var` no notifican a los bindings de QML, así
    // que sin esto el swatch, la barra y el texto no refrescan.
    function setHex(index, hex) {
        if (index < 0 || index >= root.customHex.length) return
        if (root.customHex[index] === hex) return
        var copy = root.customHex.slice()
        copy[index] = hex
        root.customHex = copy
    }

    // Clave del preview en AppTheme para el índice de la paleta.
    function previewKeyAt(index) {
        if (index < 0 || index >= root.editableSpec.length) return ""
        return root.editableSpec[index][2]
    }

    // Ruta única de edición: actualiza el hex Y retinta la interfaz en vivo.
    function editHex(index, hex) {
        if (index < 0 || index >= root.editableSpec.length) return
        root.setHex(index, hex)
        if (root.hexValid(hex)) {
            AppTheme.setPalettePreview(root.previewKeyAt(index), hex)
        }
    }

    // Empuja TODOS los hex válidos al preview (tras un undo, para que la UI
    // muestre ya el estado revertido antes de que wallust termine).
    function syncPreviews() {
        var map = {}
        for (var i = 0; i < root.editableSpec.length; i++) {
            map[root.previewKeyAt(i)] = root.customHex[i]
        }
        AppTheme.syncPalettePreview(map)
    }

    // Índice del color N en customHex (los 3 primeros entries son especiales).
    function pIdx(n) {
        return 3 + n
    }

    // ========================== DESHACER ==========================
    // Un snapshot por gesto de edición (arrastre o secuencia de tecleo).
    // Un snapshot es { type: "palette", hex: [...] } o
    //               { type: "accent",  hue, sat, light }.
    function captureUndo(force) {
        if (root.editSequenceActive && !force) return
        var snap
        if (root.selectedColorIndex >= 0) {
            snap = { type: "palette", hex: root.customHex.slice() }
        } else {
            snap = { type: "accent", hue: root.accentHue, sat: root.selectSat, light: root.selectLight }
        }
        var next = root.undoStack.concat([snap])
        if (next.length > 32) next.shift()
        root.undoStack = next
        root.editSequenceActive = true
    }

    function undoColor() {
        if (root.undoStack.length === 0) return
        if (root.applying || root.applyingCustom) return
        var snap = root.undoStack[root.undoStack.length - 1]
        root.undoStack = root.undoStack.slice(0, root.undoStack.length - 1)
        if (snap.type === "palette") {
            root.customHex = snap.hex.slice()
            root.customDirty = true
            root.syncSelectHsl()
            // Mostrar el estado revertido y re-persistirlo a las apps.
            root.syncPreviews()
            root.applyCustom(true)
        } else {
            root.accentHue = snap.hue
            root.selectSat = snap.sat
            root.selectLight = snap.light
            AppTheme.accentOverride = Qt.hsla(snap.hue / 360, snap.sat, snap.light, 1)
        }
        root.editSequenceActive = false
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

        readonly property bool isSelected: root.selectedColorIndex === colorIndex

        implicitHeight: Math.max(AppTheme.paddingBase * 2 + tf.implicitHeight, 34)
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        radius: AppTheme.radiusSmall
        color: cell.isSelected ? Qt.alpha(AppTheme.accent, 0.10)
             : cellStyle.hovered ? AppTheme.surface
             : Qt.alpha(AppTheme.fg, 0.03)
        border.width: 1
        border.color: cell.isSelected ? Qt.alpha(AppTheme.accent, 0.7)
                    : cellStyle.hovered || cell.fieldActive ? Qt.alpha(AppTheme.accent, 0.45)
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
                    onClicked: {
                        root.selectColor(cell.colorIndex)
                        tf.forceActiveFocus()
                    }
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
                        root.captureUndo()
                        root.editHex(cell.colorIndex, tf.text)
                        root.ensureColorSelected(cell.colorIndex)
                        root.customDirty = true
                    }
                    onActiveFocusChanged: {
                        tf.fieldActive = tf.activeFocus
                        if (tf.activeFocus) root.ensureColorSelected(cell.colorIndex)
                        else root.editSequenceActive = false
                    }
                    onAccepted: {
                        root.editHex(cell.colorIndex, tf.text.length === 7 ? tf.text : (tf.text.length === 6 ? "#" + tf.text : tf.text))
                        root.syncSelectHsl()
                        root.editSequenceActive = false
                    }

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

            Text {
                visible: cell.isSelected
                text: String.fromCodePoint(0xf0c9) // mirilla: editar con la barra
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontSmall
                color: AppTheme.accent
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: cellStyle
            property bool hovered: false
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.selectColor(cell.colorIndex)
                tf.forceActiveFocus()
            }
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

            // =================== EDITOR DE COLOR (BARRA) ===================
            RowLayout {
                Layout.fillWidth: true

                SectionLabel { text: root.targetLabel }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.targetHex
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textSecondary
                }

                Rectangle {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: AppTheme.radiusSmall
                    color: root.targetColor
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
                    x: Math.max(3, Math.min(parent.width - 23, (root.barHue / 360) * (parent.width - 26) + 3))
                    width: 20
                    height: 20
                    radius: 10
                    color: root.targetColor
                    border.width: 2
                    border.color: AppTheme.fg
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (event) => {
                        root.captureUndo()
                        root.setBarHueFromX(event.x, parent.width)
                    }
                    onPositionChanged: (event) => {
                        if (event.pressed) root.setBarHueFromX(event.x, parent.width)
                    }
                    onReleased: (event) => { root.editSequenceActive = false }
                }
            }

            // Pad de saturación × luminosidad (control de claro/oscuro).
            Rectangle {
                id: slPad
                Layout.fillWidth: true
                implicitHeight: 160
                radius: AppTheme.radiusSmall
                border.width: 1
                border.color: Qt.alpha(AppTheme.fg, 0.12)
                clip: true

                // Capa horizontal: blanco (izquierda) → matiz vivo (derecha).
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#ffffff" }
                        GradientStop { position: 1.0; color: Qt.hsla(root.barHue / 360, 1, 0.5, 1) }
                    }
                }

                // Capa vertical: blanco (arriba) → transparente → negro (abajo).
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#ffffff" }
                        GradientStop { position: 0.5; color: "transparent" }
                        GradientStop { position: 1.0; color: "#000000" }
                    }
                }

                // Handle arrastrable.
                Rectangle {
                    id: slHandle
                    x: Math.max(0, Math.min(parent.width - slHandle.width, root.selectSat * (parent.width - slHandle.width)))
                    y: Math.max(0, Math.min(parent.height - slHandle.height, (1 - root.selectLight) * (parent.height - slHandle.height)))
                    width: 18
                    height: 18
                    radius: 9
                    color: root.targetColor
                    border.width: 2
                    border.color: AppTheme.fg
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    onPressed: (event) => {
                        root.captureUndo()
                        root.setPadFromXY(event.x, event.y, parent.width, parent.height)
                    }
                    onPositionChanged: (event) => {
                        if (event.pressed) root.setPadFromXY(event.x, event.y, parent.width, parent.height)
                    }
                    onReleased: (event) => { root.editSequenceActive = false }
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
                    onClicked: root.resetTarget()
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

                ActionButton {
                    id: undoBtn
                    text: "Deshacer"
                    icon: String.fromCodePoint(0xf0e2) // flecha circular
                    enabled: root.canUndo && !root.applying && !root.applyingCustom
                    onClicked: root.undoColor()
                }

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

            Text {
                visible: root.applyStatus !== ""
                Layout.fillWidth: true
                text: root.applyStatus === "OK"
                    ? "Colores aplicados correctamente."
                    : "Error al aplicar. Revisa ~/.cache/wallust-apply.log."
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                color: root.applyStatus === "OK" ? AppTheme.success : AppTheme.critical
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
    // Convierte #rrggbb a componentes 0-1.
    function hexToRgb01(hex) {
        var s = root.hexValid(hex) ? hex : "#555555"
        return {
            r: parseInt(s.slice(1, 3), 16) / 255,
            g: parseInt(s.slice(3, 5), 16) / 255,
            b: parseInt(s.slice(5, 7), 16) / 255
        }
    }

    function rgb01ToHex(r, g, b) {
        function ch(v) {
            var n = Math.max(0, Math.min(255, Math.round(v * 255)))
            var h = n.toString(16)
            return h.length === 1 ? "0" + h : h
        }
        return "#" + ch(r) + ch(g) + ch(b)
    }

    // HSL (h 0-360, s/l 0-1) a partir de un hex.
    function hslFromHex(hex) {
        var c = root.hexToRgb01(hex)
        var r = c.r, g = c.g, b = c.b
        var max = Math.max(r, g, b), min = Math.min(r, g, b)
        var l = (max + min) / 2
        var h = 0, s = 0
        if (max !== min) {
            var d = max - min
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
            if (max === r) h = ((g - b) / d + (g < b ? 6 : 0))
            else if (max === g) h = (b - r) / d + 2
            else h = (r - g) / d + 4
            h *= 60
        }
        return { h: h, s: s, l: l }
    }

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

    // Objetivo activo de la barra de matiz (color de paleta o acento).
    readonly property int barHue: root.selectedColorIndex >= 0
        ? Math.round(root.hslFromHex(root.customHex[root.selectedColorIndex]).h)
        : root.accentHue
    readonly property string targetLabel: root.selectedColorIndex >= 0
        ? ("COLOR " + (root.editableSpec[root.selectedColorIndex] ? root.editableSpec[root.selectedColorIndex][0] : "")).toUpperCase()
        : "COLOR DE ACENTO"
    readonly property string targetHex: root.selectedColorIndex >= 0
        ? root.customHex[root.selectedColorIndex]
        : AppTheme.accent.toString()
    readonly property color targetColor: root.selectedColorIndex >= 0
        ? root.hexColor(root.customHex[root.selectedColorIndex])
        : AppTheme.accent

    function setBarHueFromX(x, width) {
        var h = Math.max(0, Math.min(360, (x / width) * 360))
        if (root.selectedColorIndex >= 0) {
            var col = Qt.hsla(h / 360, root.selectSat, root.selectLight, 1)
            root.editHex(root.selectedColorIndex, root.rgb01ToHex(col.r, col.g, col.b))
            root.customDirty = true
        } else {
            root.accentHue = h
            AppTheme.accentOverride = Qt.hsla(h / 360, root.selectSat, root.selectLight, 1)
        }
    }

    // Actualiza saturación y luminosidad (pad 2D) del objetivo de la barra.
    // X = saturación (0-1), Y = luminosidad (0-1, arriba=claro/abajo=oscuro).
    function setPadFromXY(x, y, width, height) {
        var sat = Math.max(0, Math.min(1, x / width))
        var light = Math.max(0, Math.min(1, 1 - (y / height)))
        root.selectSat = sat
        root.selectLight = light
        if (root.selectedColorIndex >= 0) {
            var col = Qt.hsla(root.barHue / 360, sat, light, 1)
            root.editHex(root.selectedColorIndex, root.rgb01ToHex(col.r, col.g, col.b))
            root.customDirty = true
        } else {
            AppTheme.accentOverride = Qt.hsla(root.accentHue / 360, sat, light, 1)
        }
    }

    // Restablece el objetivo de la barra: color de paleta a su valor de la
    // paleta wallust activa, o el acento a su matiz base.
    function resetTarget() {
        if (root.selectedColorIndex >= 0) {
            var spec = root.editableSpec[root.selectedColorIndex]
            var orig = root.palValue(spec[1], spec[2], "")
            if (orig) {
                root.captureUndo()
                root.editHex(root.selectedColorIndex, root.colorToHex(orig))
                root.syncSelectHsl()
                root.customDirty = true
            }
        } else {
            root.captureUndo()
            root.resetAccent()
            root.syncAccentSl()
        }
    }

    function resetAccent() {
        root.accentHue = root.baseAccentHue
        AppTheme.accentOverride = "transparent"
    }
}