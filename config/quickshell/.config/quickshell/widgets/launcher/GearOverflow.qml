// widgets/launcher/GearOverflow.qml
// Satélites laterales: mini engranajes decorativos adosados a los lados del
// engranaje central (sin celdas de apps). Rotan en bloque con el dial
// principal (misma mecánica: la silueta sigue disc.rotation).
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.globals

Item {
    id: root

    // Referencia al Gear principal (para dibujado de la silueta).
    property var gearRef: null
    readonly property real satRadius: AppTheme.launcherSatRadius
    readonly property real satGap: AppTheme.launcherSatGap
    readonly property real mainRadius: AppTheme.launcherGearRadius
    readonly property real cx: root.mainRadius + root.satGap + root.satRadius
    readonly property real satOuter: AppTheme.launcherSatRadius + AppTheme.launcherSatToothH
    // Rotación sincronizada con el dial principal.
    readonly property real satSpin: root.gearRef ? root.gearRef.dialRotation : 0

    implicitWidth: (root.cx + root.satOuter) * 2
    implicitHeight: root.satOuter * 2

    // ============================================================
    // SATÉLITE IZQUIERDO (decorativo)
    // ============================================================
    Item {
        id: satLeft

        x: 0
        y: 0
        width: root.satOuter * 2
        height: root.satOuter * 2

        Canvas {
            id: satLeftBody

            anchors.fill: parent
            antialiasing: true
            rotation: root.satSpin
            Component.onCompleted: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                if (!gearRef)
                    return ;

                const ctx = satLeftBody.getContext("2d");
                ctx.reset();
                const cx = satLeftBody.width / 2;
                const cy = satLeftBody.height / 2;
                gearRef.buildGearPath(ctx, cx, cy, AppTheme.launcherSatRadius, AppTheme.launcherSatToothH, LauncherState.gearSize);
                const grad = ctx.createRadialGradient(cx, cy, AppTheme.launcherSatRadius * 0.4, cx, cy, AppTheme.launcherSatRadius + 6);
                grad.addColorStop(0, Qt.alpha(AppTheme.color4, 0.7));
                grad.addColorStop(1, Qt.alpha(AppTheme.color4, 0.4));
                ctx.fillStyle = grad;
                ctx.fill();
                ctx.strokeStyle = Qt.alpha(AppTheme.color4, 0.8);
                ctx.lineWidth = 2.5;
                ctx.stroke();
            }
        }

    }

    // ============================================================
    // SATÉLITE DERECHO (decorativo)
    // ============================================================
    Item {
        id: satRight

        x: root.cx * 2
        y: 0
        width: root.satOuter * 2
        height: root.satOuter * 2

        Canvas {
            id: satRightBody

            anchors.fill: parent
            antialiasing: true
            rotation: root.satSpin
            Component.onCompleted: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                if (!gearRef)
                    return ;

                const ctx = satRightBody.getContext("2d");
                ctx.reset();
                const cx2 = satRightBody.width / 2;
                const cy2 = satRightBody.height / 2;
                gearRef.buildGearPath(ctx, cx2, cy2, AppTheme.launcherSatRadius, AppTheme.launcherSatToothH, LauncherState.gearSize);
                const grad = ctx.createRadialGradient(cx2, cy2, AppTheme.launcherSatRadius * 0.4, cx2, cy2, AppTheme.launcherSatRadius + 6);
                grad.addColorStop(0, Qt.alpha(AppTheme.color4, 0.7));
                grad.addColorStop(1, Qt.alpha(AppTheme.color4, 0.4));
                ctx.fillStyle = grad;
                ctx.fill();
                ctx.strokeStyle = Qt.alpha(AppTheme.color4, 0.8);
                ctx.lineWidth = 2.5;
                ctx.stroke();
            }
        }

    }

}