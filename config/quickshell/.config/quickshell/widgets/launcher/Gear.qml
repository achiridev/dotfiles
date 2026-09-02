// widgets/launcher/Gear.qml
// Engranaje principal del launcher: la SILUETA (Canvas) gira junto con los
// 8 cuadros de apps, soldados a la rueda (rueda real). El cuadro que asienta
// en el tope —(offset % 8)— es el FOCO y muestra la app seleccionada.
//   - reposo: rot = -(offset % N) * step  (retargetable, easing OutCubic);
//     cada paso = un "clic de trinquete"; → gira ANTIHORARIO.
//   - búsqueda: "spin" de +360° (InOutCubic); al terminar se normaliza al
//     instante (la pose es idéntica mod 360).
// Mapeo del anillo: cuadro físico index i -> AppModel.wheelAt(i) ==
// ringApps[8*floor(offset/8) + i]; el cuadro (offset % 8) queda arriba y es
// el foco (muestra ringApps[offset]). El rebase a página nueva (offset += 8)
// hace snap del dial a orientación 0 con los datos de la página siguiente.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.globals
import qs.services

Item {
    // ============================================================
    // MECÁNICA ROTACIÓN (reposo animado / spin manual retargetable)
    // La rotación del dial se mueve SOLO desde aquí (nunca hay un Behavior
    // sobre rotation) para poder teletransportar al normalizar el spin.
    // ============================================================

    id: root

    // === API (consumida por GearRoot / satélites) ===
    property int restOffset: AppModel.offset
    property bool spinActive: false
    property real radius: AppTheme.launcherGearRadius
    property real toothH: AppTheme.launcherGearToothH
    property real durationRest: AppTheme.launcherAnimRest
    property real durationSpin: AppTheme.launcherAnimSpin
    readonly property real outerR: root.radius + root.toothH // la silueta define el bounding

    signal clickedSlot(var app)

    // Pose de reposo del dial (módulo N: la corona completa cubre 360°).
    // Negativa: *avanzar* (→) hace girar la rueda en sentido ANTIHORARIO.
    function restPose() {
        return -(root.restOffset % LauncherState.gearSize) * LauncherState.step;
    }

    function poseTo(pose, animated) {
        if (animated && pose !== disc.rotation) {
            poseAnim.stop();
            poseAnim.from = disc.rotation;
            poseAnim.to = pose;
            poseAnim.duration = root.durationRest;
            poseAnim.start();
        } else {
            disc.rotation = pose;
        }
    }

    // Inicio de arrastre al entrar en modo búsqueda.
    function beginSpin() {
        root.spinActive = true;
        const base = root.restPose();
        root.poseTo(base, false);
        spinAnim.from = base;
        spinAnim.to = base + 360;
        spinAnim.duration = root.durationSpin;
        spinAnim.start();
    }

    // Re-encauza el spin cuando cambia el resultado durante la escritura:
    // se re-ancla al nuevo punto final (siempre base+360, vuelta adelante).
    function retargetSpin() {
        spinAnim.stop();
        spinAnim.from = disc.rotation;
        spinAnim.to = root.restPose() + 360;
        spinAnim.duration = root.durationSpin;
        spinAnim.restart();
    }

    function endSpin() {
        spinAnim.stop();
        poseAnim.stop();
        root.spinActive = false;
        disc.rotation = root.restPose();
    }

    // ============================================================
    // SILUETA: genera UN único subcamino continuo de engranaje (disco +
    // dientes). Sin fill/stroke: cada canvas (principal o satélite) lo pinta
    // con su gradiente y contorno propios.
    // ============================================================
    function buildGearPath(ctx, cx, cy, R, toothH, teeth) {
        const outer = R + toothH / 2;
        const rim = R - toothH / 2;
        const step = (Math.PI * 2) / teeth;
        const toothW = step * 0.6; // anchura angular de cada diente
        ctx.beginPath();
        for (let i = 0; i < teeth; ++i) {
            // Fase: el diente queda CENTRADO en el ángulo -90 + i*step (el de
            // su celda/slot), no desplazado medio ancho: diente ≡ cuadro.
            const ta = -Math.PI / 2 + i * step - toothW / 2;
            const te = ta + toothW;
            if (i === 0)
                ctx.moveTo(cx + Math.cos(ta) * outer, cy + Math.sin(ta) * outer);

            // vano exterior del diente
            ctx.arc(cx, cy, outer, ta, te, false);
            // flanco hacia dentro (almohadilla/raíz del diente)
            ctx.lineTo(cx + Math.cos(te) * rim, cy + Math.sin(te) * rim);
            // canal interior entre dientes
            const nx = ta + step;
            ctx.arc(cx, cy, rim, te, nx, false);
            // flanco saliente hacia el siguiente diente
            ctx.lineTo(cx + Math.cos(nx) * outer, cy + Math.sin(nx) * outer);
        }
        ctx.closePath();
    }

    width: root.outerR * 2
    height: root.outerR * 2
    onRestOffsetChanged: {
        if (root.spinActive)
            root.retargetSpin();
        else
            root.poseTo(root.restPose(), true);
    }

    // ============================================================
    // DIAL (gira SOLO la silueta mecánica)
    // ============================================================
    Item {
        id: disc

        anchors.centerIn: parent
        width: parent.width
        height: parent.height

        // --- Silueta mecánica ---
        Canvas {
            id: gearBody

            anchors.fill: parent
            antialiasing: true
            z: 0
            Component.onCompleted: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const n = LauncherState.gearSize;
                const cx = gearBody.width / 2;
                const cy = gearBody.height / 2;
                const ctx = gearBody.getContext("2d");
                ctx.reset();
                root.buildGearPath(ctx, cx, cy, root.radius, root.toothH, n);
                // Cuerpo casi opaco con gradiente del color de acento.
                const grad = ctx.createRadialGradient(cx, cy, root.radius * 0.2, cx, cy, root.radius + root.toothH);
                grad.addColorStop(0, Qt.alpha(AppTheme.color4, 0.96));
                grad.addColorStop(0.55, Qt.alpha(AppTheme.color4, 0.84));
                grad.addColorStop(1, Qt.alpha(AppTheme.color4, 0.7));
                ctx.fillStyle = grad;
                ctx.fill();
                // Contorno exterior con acento del tema.
                ctx.strokeStyle = Qt.alpha(AppTheme.color4, 0.95);
                ctx.lineWidth = 3;
                ctx.stroke();
                // Aro interior (inset) acentuado.
                ctx.beginPath();
                ctx.arc(cx, cy, root.radius - root.toothH * 0.15, 0, Math.PI * 2);
                ctx.strokeStyle = Qt.alpha(AppTheme.color4, 0.55);
                ctx.lineWidth = 1.5;
                ctx.stroke();
            }

            Connections {
                function onColorsChanged() {
                    gearBody.requestPaint();
                }

                target: AppTheme
            }

        }

    }

    // ============================================================
    // CORONA: 8 cuadros soldados a la rueda que rotan con el dial en
    // bloque; el cuadro que asienta arriba ((offset % 8)) es el foco y
    // muestra ringApps[offset].
    // ============================================================
    Repeater {
        model: LauncherState.toothCount

        delegate: Item {
            id: cell

            // Origen en el centro del engranaje para coordenadas polares.
            x: disc.width / 2
            y: disc.height / 2
            width: 0
            height: 0

            GearSlot {
                angleDeg: -90 + index * LauncherState.step + disc.rotation
                orbitRadius: root.radius
                cellW: AppTheme.launcherSlotW
                cellH: AppTheme.launcherSlotH
                iconPx: AppTheme.launcherIconPx
                // Foco = cuadro (offset % 8): gira con la rueda y llega arriba
                // mostrando la app seleccionada ringApps[offset].
                isFocus: index === AppModel.mod(AppModel.offset, 8)
                app: AppModel.wheelAt(index)
                onClicked: (app) => {
                    return root.clickedSlot(app);
                }
            }

        }

    }

    // Animación de reposo: reasentamiento retargetable con easing OutCubic.
    NumberAnimation {
        id: poseAnim

        target: disc
        property: "rotation"
        duration: root.durationRest
        easing.type: Easing.OutCubic
    }

    // Rotación manual del "spin": vuelta completa de arrastre.
    NumberAnimation {
        id: spinAnim

        target: disc
        property: "rotation"
        duration: root.durationSpin
        easing.type: Easing.InOutCubic
    }

}
