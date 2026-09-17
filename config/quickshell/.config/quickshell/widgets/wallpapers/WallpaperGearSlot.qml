// widgets/wallpapers/WallpaperGearSlot.qml
// Mini-engranaje del tablero de wallpapers: silueta de dientes (Canvas) con la
// imagen del fondo dentro (disco circular). Al cambiar el foco, cada engranaje
// "muerde" un paso (giro) y reproduce como un engranaje real; el del centro es
// el foco (escala + borde de acento). Indica el "Actual" (✓) y "Aplicando…".
// Click = aplicar; click derecho = asignar a carpeta.
import QtQuick
import Quickshell

import qs.globals
import qs.services

Item {
    id: root

    required property var item          // wallpaper item o null
    property bool isFocus: false

    signal clicked(var item)
    signal contextRequested(var item)

    readonly property string wpId: item ? String(item.id) : ""
    readonly property bool isCurrent: wpId !== "" && WallpaperService.currentId === wpId
    readonly property bool isApplying: wpId !== "" && WallpaperService.applyingId === wpId
    readonly property bool hovered: hoverHandler.hovered

    // Altura de los dientes PROPORCIONAL al tamaño del engranaje (misma
    // proporción que el launcher, ~20% del radio), con piso en el tema.
    // Un toothH fijo hacía que los engranajes grandes parecieran discos con
    // dientes diminutos.
    readonly property real toothH: Math.max(AppTheme.wpGearToothH, Math.min(root.size * 0.09, 15))
    // R calculado dejando margen ANTIALIAS: con gearR = width/2 - toothH las
    // puntas de los dientes quedan toothH/2 dentro del canvas (igual que el
    // launcher). Con solo toothH/2, outer == width/2 y un círculo inscrito al
    // borde biseca las puntas de los 4 dientes cardinales (0/90/180/270°).
    readonly property real gearR: root.width / 2 - root.toothH
    // Preview "congelada": el disco (imagen) no crece con el engranaje — se
    // topa en `wpGearPreviewCap` mientras la silueta de dientes puede agrandarse
    // (el scale de foco se aplica SOLO a la silueta, no al disco).
    readonly property real imgD: Math.min((root.gearR - root.toothH * 1.25) * 2, AppTheme.wpGearPreviewCap)
    readonly property int teeth: 12

    // Tamaño del engranaje (dimensionado por el tablero; default el del tema).
    property real size: AppTheme.wpGearSlotW

    width: root.size
    height: root.size
    z: root.isFocus ? 5 : (root.hovered ? 4 : 1)

    // Progreso de foco 0..1: anima el color del cuerpo y el anillo al GANAR y
    // al PERDER el foco (único engranaje tintado = el del foco).
    property real focusProgress: root.isFocus ? 1.0 : 0.0

    Behavior on focusProgress {
        NumberAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
    }

    // ---- Contadores de "paso" ----
    property int _spinTarget: 0

    function biteStep(delta) {
        // "Muerde" un paso de engranaje por posición movida (sentido relativo).
        // Solo rota la SILUETA de dientes (gearCanvas); la imagen y los badges
        // quedan con rotación 0 para que la preview nunca quede de lado.
        root._spinTarget = root._spinTarget - delta * (360 / AppTheme.wpBoardCols);
        spinAnim.stop();
        spinAnim.from = gearCanvas.rotation;
        spinAnim.to = root._spinTarget;
        spinAnim.start();
    }

    NumberAnimation {
        id: spinAnim
        target: gearCanvas
        property: "rotation"
        duration: AppTheme.wpGearSpinMs
        easing.type: Easing.OutCubic
    }

    onIsFocusChanged: gearCanvas.requestPaint()
    onIsCurrentChanged: gearCanvas.requestPaint()
    onHoveredChanged: gearCanvas.requestPaint()
    onFocusProgressChanged: gearCanvas.requestPaint()

    // ---- Silueta del mini-engranaje (disc + dientes) ----
    Canvas {
        id: gearCanvas
        anchors.fill: parent
        antialiasing: true
        transformOrigin: Item.Center
        // El scale de foco/hover se aplica SOLO a la silueta: la preview
        // (disco) y los badges quedan a tamaño base (diseño "preview congelada").
        scale: root.isFocus ? AppTheme.wpGearFocusScale : (root.hovered ? 1.04 : 1.0)
        z: 0

        Behavior on scale {
            NumberAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = gearCanvas.getContext("2d");
            ctx.reset();
            const cx = gearCanvas.width / 2;
            const cy = gearCanvas.height / 2;
            root.buildGearPath(ctx, cx, cy, root.gearR, root.toothH, root.teeth);
            // Cuerpo: SOLO el engranaje del FOCO se tiñe de acento (mezclado
            // con `focusProgress` para animarlo al ganar/perder). El resto es
            // oscuro translúcido; el "Actual" ya no pinta el cuerpo.
            const t = root.focusProgress;
            const mix = (a, b) => a + (b - a) * t;
            const base = Qt.alpha(AppTheme.bg, 0.5);
            const acc = Qt.lighter(AppTheme.accent, 1.15);
            const c0 = Qt.rgba(mix(base.r, acc.r), mix(base.g, acc.g), mix(base.b, acc.b), mix(0.5, 0.85));
            const c1 = Qt.rgba(mix(base.r, acc.r), mix(base.g, acc.g), mix(base.b, acc.b), mix(0.64, 0.92));
            const c2 = Qt.rgba(mix(base.r, acc.r), mix(base.g, acc.g), mix(base.b, acc.b), mix(0.78, 1.0));
            const grad = ctx.createRadialGradient(cx, cy, root.gearR * 0.2, cx, cy, root.width / 2);
            grad.addColorStop(0, c0);
            grad.addColorStop(0.7, c1);
            grad.addColorStop(1, c2);
            ctx.fillStyle = grad;
            ctx.fill();
            // Contorno: el FOCO lleva el anillo de acento (el único en color,
            // grueso y con transición también al liberar/conceder el foco);
            // el Actual un aro fino del mismo acento; hover sutil; reposo neutro.
            let ring;
            let ringW;
            if (t > 0) {
                ring = Qt.alpha(AppTheme.accent, 0.6 + t * 0.4);
                ringW = 2 + t * 2;
            } else if (root.isCurrent) {
                ring = Qt.alpha(AppTheme.accent, 0.35);
                ringW = 1.5;
            } else if (root.hovered) {
                ring = Qt.alpha(AppTheme.accent, 0.55);
                ringW = 1.5;
            } else {
                ring = Qt.alpha(AppTheme.borderColor, 0.7);
                ringW = 1.5;
            }
            ctx.strokeStyle = ring;
            ctx.lineWidth = ringW;
            ctx.stroke();
            // Aro interior para "leer" la corona de dientes (acento con foco).
            // Se traza DENTRO del disco sólido (rim = gearR - toothH/2) para
            // no quedar fragmentado en los valles entre dientes: siempre es un
            // círculo continuo, nunca arcos sueltos fuera de la silueta.
            ctx.beginPath();
            ctx.arc(cx, cy, root.gearR - root.toothH * 0.75, 0, Math.PI * 2);
            ctx.strokeStyle = Qt.alpha(t > 0 ? AppTheme.accent : AppTheme.fg, 0.45);
            ctx.lineWidth = 1;
            ctx.stroke();
        }
        Connections {
            target: AppTheme
            function onColorsChanged() { gearCanvas.requestPaint() }
        }
    }

    // ---- Imagen del wallpaper dentro del engranaje (disco) ----
    // Estático y a tamaño base: no escala con el foco ni fluye al cambiar de
    // contenido (el scale de foco vive en `gearCanvas`, no en el root).
    Item {
        id: previewDisc
        anchors.centerIn: parent
        width: root.imgD
        height: root.imgD
        z: 1

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.alpha(AppTheme.bg, 0.9)
            clip: true
            // Borde de acento del disco: señal de foco siempre visible (el foco
            // es el único engranaje con este anillo sobre la imagen).
            border.color: Qt.alpha(AppTheme.accent, 0.75 + root.focusProgress * 0.25)
            border.width: root.focusProgress > 0 ? 2.5 : 0

            Behavior on border.color {
                ColorAnimation { duration: AppTheme.wpAnimFast; easing.type: Easing.OutCubic }
            }

            LazyImage {
                anchors.fill: parent
                source: root.item ? root.item.thumb : ""
                maxSourceWidth: 288
            }
        }
    }

    // ---- Badge "Actual" (esquina superior del disco) ----
    Rectangle {
        visible: root.isCurrent && !root.isApplying
        anchors {
            top: previewDisc.top
            right: previewDisc.right
            topMargin: 1
            rightMargin: 1
        }
        width: 18
        height: 18
        radius: 9
        color: AppTheme.wpCurrentRing
        z: 3
        Text {
            anchors.centerIn: parent
            text: "✓"
            font.family: AppTheme.fontLayout
            font.pixelSize: 10
            font.weight: Font.Bold
            color: AppTheme.bg
        }
    }

    // ---- Overlay "Aplicando…" ----
    Rectangle {
        visible: root.isApplying
        anchors.fill: parent
        radius: parent.width / 2
        color: Qt.alpha(AppTheme.bg, 0.6)
        z: 4
        Text {
            anchors.centerIn: parent
            text: "Aplicando…"
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontTiny
            font.weight: Font.Bold
            color: AppTheme.warning
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.clicked(root.item)
            else
                root.contextRequested(root.item)
        }
    }

    // Silueta de engranaje (disc + dientes) — mismo generador que el launcher.
    function buildGearPath(ctx, cx, cy, R, toothH, teeth) {
        const outer = R + toothH / 2;
        const rim = R - toothH / 2;
        const step = (Math.PI * 2) / teeth;
        const toothW = step * 0.6;
        ctx.beginPath();
        for (let i = 0; i < teeth; ++i) {
            const ta = -Math.PI / 2 + i * step - toothW / 2;
            const te = ta + toothW;
            if (i === 0)
                ctx.moveTo(cx + Math.cos(ta) * outer, cy + Math.sin(ta) * outer);
            ctx.arc(cx, cy, outer, ta, te, false);
            ctx.lineTo(cx + Math.cos(te) * rim, cy + Math.sin(te) * rim);
            const nx = ta + step;
            ctx.arc(cx, cy, rim, te, nx, false);
            ctx.lineTo(cx + Math.cos(nx) * outer, cy + Math.sin(nx) * outer);
        }
        ctx.closePath();
    }
}