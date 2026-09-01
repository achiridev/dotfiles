// widgets/launcher/GearOverflow.qml
// Satélites laterales: mini engranajes ESTÁTICOS adosados a los lados del
// engranaje central, que muestran el overflow de la lista.
// El izquierdo cubre los `satelliteCount` antecesores del foco
// (ring[offset-1..offset-3]); el derecho los que siguen a la corona
// (ring[offset+8..offset+10]). Dentro del satélite, los dientes permanecen
// con la corona arriba y el contenido erguido (no rotan con la rueda).
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.globals
import qs.services

Item {
    id: root

    // Referencia al Gear principal (para clics y dibujado de la silueta).
    property var gearRef: null
    readonly property real satRadius: AppTheme.launcherSatRadius
    readonly property real satGap: AppTheme.launcherSatGap
    readonly property real mainRadius: AppTheme.launcherGearRadius
    readonly property real cx: root.mainRadius + root.satGap + root.satRadius

    implicitWidth: (root.cx + root.satRadius) * 2
    implicitHeight: root.satRadius * 2

    // ============================================================
    // SATÉLITE IZQUIERDO (antecesores del foco)
    // ============================================================
    Item {
        id: satLeft

        x: -root.cx - root.satRadius
        y: -root.satRadius
        width: root.satRadius * 2
        height: root.satRadius * 2

        Canvas {
            id: satLeftBody

            anchors.fill: parent
            antialiasing: true
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

        Item {
            x: parent.width / 2
            y: parent.height / 2
            width: 0
            height: 0

            Repeater {
                model: LauncherState.satelliteCount

                delegate: Item {
                    // Origen en el centro del satélite (el Item que lo envuelve
                    // ya está centrado; aquí NO se vuelve a desplazar).
                    x: 0
                    y: 0
                    width: 0
                    height: 0

                    GearSlot {
                        toothIndex: -LauncherState.satelliteCount + index
                        angleDeg: -90 - index * LauncherState.step
                        orbitRadius: root.satRadius
                        cellW: 56
                        cellH: 56
                        iconPx: 26
                        showLabel: false
                        counterRot: 0
                        // Anillo nuevo: la corona cubre ring[offset..offset+7]; el satélite
                        // izquierdo muestra los 3 anteriores (offset-1..-3).
                        app: AppModel.appAt(-1 - index)
                        onClicked: (app) => {
                            return root.gearRef.clickedSlot(app);
                        }
                    }

                }

            }

        }

    }

    // --------------------- DERECHO ---------------------
    Item {
        id: satRight

        x: root.cx - root.satRadius
        y: -root.satRadius
        width: root.satRadius * 2
        height: root.satRadius * 2

        Canvas {
            id: satRightBody

            anchors.fill: parent
            antialiasing: true
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

        Item {
            x: parent.width / 2
            y: parent.height / 2
            width: 0
            height: 0

            Repeater {
                model: LauncherState.satelliteCount

                delegate: Item {
                    x: 0
                    y: 0
                    width: 0
                    height: 0

                    GearSlot {
                        toothIndex: LauncherState.gearSize + index
                        angleDeg: -90 + index * LauncherState.step
                        orbitRadius: root.satRadius
                        cellW: 56
                        cellH: 56
                        iconPx: 26
                        showLabel: false
                        counterRot: 0
                        // Anillo nuevo: la corona cubre ring[offset..offset+7]; el satélite
                        // derecho muestra los 3 siguientes (offset+8..+10).
                        app: AppModel.appAt(LauncherState.gearSize + index)
                        onClicked: (app) => {
                            return root.gearRef.clickedSlot(app);
                        }
                    }

                }

            }

        }

    }

}
