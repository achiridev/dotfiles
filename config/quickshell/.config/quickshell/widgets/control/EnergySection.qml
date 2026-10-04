// widgets/control/EnergySection.qml
// Sección "Energía" del Panel de Control.
//
// Estructura (de arriba abajo):
//   1. Modos de energía   → los 4 modos de ~/.local/bin/battery-mode
//   2. Aviso de reinicio → solo si hay un cambio de GPU pendiente de aplicar
//   3. Batería            → % / estado / tiempo / salud / tensión (UPower+sysfs)
//   4. Carga y temperatura→ EPP, frecuencias, heatmap de núcleos, GPU
//   5. Estado del sistema → governor, turbo, TLP, auto-cpufreq, sensores
//
// TODO lo que se muestra es de SOLO LECTURA: nada escribe en /sys ni pide
// sudo. Los únicos controles que cambian algo son los 4 modos de la cabecera.
// Los datos caros (nvidia-smi, sondeo de núcleos) solo se recogen con
// `detailMode`, que el panel activa mientras esta pestaña está visible.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.globals

Item {
    id: root

    // Altura natural de la sección (para que el panel se ajuste).
    readonly property int sectionHeight: 320

    // ============================== COMPONENTES =============================

    // Botón de modo de energía (solo lectura del estado; el clic sí aplica).
    component ModeButton: Rectangle {
        id: btn
        property string mode: ""
        property string icon: ""
        property string title: ""
        property string desc: ""

        readonly property bool isActive: BatteryService.activeMode === mode
        // El modo pedido pero aún no aplicado (GPU pendiente de reiniciar):
        // se marca con un borde discontinuo para no confundir con el activo.
        readonly property bool isPending: BatteryService.gpuTarget !== ""
            && modeForTarget(BatteryService.gpuTarget) === btn.mode
            && !btn.isActive

        function modeForTarget(t) {
            // gpuTarget == gpuMode real + lo que hay que aplicar tras reboot.
            if (t === "off") return "off"
            if (t === "low") return "low"
            if (t === "integrated") return "high"
            if (t === "nvidia") return "gaming"
            return ""
        }

        Layout.fillWidth: true
        implicitHeight: btnRow.implicitHeight + AppTheme.paddingLarge * 2
        radius: AppTheme.radiusSmall
        color: isActive ? Qt.alpha(AppTheme.accent, 0.16)
             : mouse.containsMouse ? AppTheme.surface
             : Qt.alpha(AppTheme.fg, 0.03)
        border.width: isPending ? 2 : 1
        border.color: isActive ? Qt.alpha(AppTheme.accent, 0.55)
                     : isPending ? Qt.alpha(AppTheme.warning, 0.6)
                     : Qt.alpha(AppTheme.fg, 0.08)

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
                font.pixelSize: 22
                color: btn.isActive ? AppTheme.accent
                     : btn.isPending ? AppTheme.warning : AppTheme.textSecondary
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
                    color: btn.isActive ? AppTheme.accent
                         : btn.isPending ? AppTheme.warning : AppTheme.fg
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

    // Pill genérica: icono + etiqueta + valor coloreado.
    component StatusPill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property string value: ""
        property color c: AppTheme.accent

        implicitWidth: pillRow.implicitWidth + AppTheme.paddingBase * 2 + 4
        implicitHeight: pillRow.implicitHeight + AppTheme.paddingSmall * 2
        radius: height / 2
        color: Qt.alpha(c, 0.10)
        border.width: 1
        border.color: Qt.alpha(c, 0.28)

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

        RowLayout {
            id: pillRow
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: 6

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

            Item { Layout.fillWidth: true }

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

    // Rótulo de bloque ("MODO DE ENERGÍA", "BATERÍA"...), con nota opcional a
    // la derecha.
    component SectionLabel: RowLayout {
        id: sl
        property string title: ""
        property string note: ""

        Layout.fillWidth: true
        spacing: AppTheme.paddingBase

        Text {
            text: sl.title
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontSmall
            font.weight: Font.Bold
            font.letterSpacing: 1.5
            color: AppTheme.textSecondary
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: sl.note !== ""
            text: sl.note
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontSmall
            color: AppTheme.textTertiary
        }
    }

    // Tarjeta: fondo sutil para agrupar un bloque de datos.
    component Card: Rectangle {
        id: cardBox
        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + AppTheme.paddingLarge * 2
        radius: AppTheme.radiusSmall
        color: Qt.alpha(AppTheme.fg, 0.025)
        border.width: 1
        border.color: Qt.alpha(AppTheme.fg, 0.07)

        default property alias content: cardLayout.data

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: AppTheme.paddingLarge
            spacing: AppTheme.paddingBase
        }
    }

    // Barra de progreso horizontal (batería y frecuencia).
    component MetricBar: Rectangle {
        id: mbar
        property real fraction: 0        // 0..1
        property color fillColor: AppTheme.accent
        property string trackColor: Qt.alpha(AppTheme.fg, 0.10)

        Layout.fillWidth: true
        implicitHeight: 8
        radius: height / 2
        color: mbar.trackColor

        Behavior on fillColor { ColorAnimation { duration: 300 } }

        Rectangle {
            width: Math.max(0, Math.min(1, mbar.fraction)) * parent.width
            height: parent.height
            radius: parent.radius
            color: mbar.fillColor

            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    // Banner informativo (reinicio pendiente).
    component Banner: Rectangle {
        id: banner
        property string msg: ""
        property string note: ""
        property color c: AppTheme.warning

        Layout.fillWidth: true
        implicitHeight: bannerRow.implicitHeight + AppTheme.paddingBase * 2
        radius: AppTheme.radiusSmall
        color: Qt.alpha(banner.c, 0.10)
        border.width: 1
        border.color: Qt.alpha(banner.c, 0.35)

        RowLayout {
            id: bannerRow
            anchors.fill: parent
            anchors.margins: AppTheme.paddingBase
            spacing: AppTheme.paddingBase

            Text {
                text: String.fromCodePoint(0xf07a) // ↻ reboot
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontLarge
                color: banner.c
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: banner.msg
                    elide: Text.ElideRight
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontBase
                    font.weight: Font.Bold
                    color: banner.c
                }

                Text {
                    Layout.fillWidth: true
                    visible: banner.note !== ""
                    text: banner.note
                    elide: Text.ElideRight
                    font.family: AppTheme.fontLayout
                    font.pixelSize: AppTheme.fontSmall
                    color: AppTheme.textSecondary
                }
            }
        }
    }

    // Celda del heatmap de núcleos: etiqueta arriba, temperatura abajo.
    component CoreCell: Rectangle {
        id: cell
        required property string coreLabel
        required property int temp

        readonly property color c: SystemStatsService.statusColor(cell.temp)

        Layout.fillWidth: true
        implicitHeight: 46
        radius: AppTheme.radiusSmall
        color: Qt.alpha(cell.c, 0.12)
        border.width: 1
        border.color: Qt.alpha(cell.c, 0.3)

        Behavior on color { ColorAnimation { duration: 400 } }
        Behavior on border.color { ColorAnimation { duration: 400 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: cell.coreLabel
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                color: AppTheme.textTertiary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: cell.temp + "°"
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontBase
                font.weight: Font.Bold
                color: cell.c
                Behavior on color { ColorAnimation { duration: 400 } }
            }
        }
    }

    // ================================ UI ================================

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: root.width
            spacing: AppTheme.paddingBase

            // ---------------------- 1. MODOS DE ENERGÍA ----------------------
            SectionLabel {
                title: "MODO DE ENERGÍA"
                note: "requiere sudo"
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: AppTheme.paddingSmall
                rowSpacing: AppTheme.paddingSmall

                ModeButton { mode: "off"; icon: String.fromCodePoint(0xf0082); title: "Normal"; desc: "GPU híbrida · CPU auto" }
                ModeButton { mode: "low"; icon: String.fromCodePoint(0xf007b); title: "Ahorro"; desc: "powersave · turbo off" }
                ModeButton { mode: "high"; icon: String.fromCodePoint(0xf186); title: "Ahorro máx."; desc: "solo iGPU · BT off · dpms" }
                ModeButton { mode: "gaming"; icon: String.fromCodePoint(0xf0e7); title: "Gaming"; desc: "GPU dedicada · performance" }
            }

            // ------------------ 2. AVISO DE REINICIO PENDIENTE ---------------
            Banner {
                visible: BatteryService.gpuRebootPending
                c: AppTheme.warning
                msg: "Reinicia para aplicar: " + BatteryService.gpuTargetName
                note: "Ahora está en " + (BatteryService.gpuMode || "?") + ". "
                    + "El modo configurado se aplica al reiniciar."
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            // -------------------------- 3. BATERÍA --------------------------
            SectionLabel {
                title: "BATERÍA"
                note: BatteryService.vendor !== "" && BatteryService.modelName !== ""
                    ? BatteryService.vendor + " " + BatteryService.modelName
                    : ""
            }

            Card {
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    // -- cabecera: % grande + estado + tiempo restante --
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: AppTheme.paddingBase

                        Text {
                            text: BatteryService.batteryIcon
                            font.family: AppTheme.fontMono
                            font.pixelSize: 34
                            color: BatteryService.levelColor(BatteryService.percentage)
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }

                        Text {
                            text: BatteryService.percentage + "%"
                            font.family: AppTheme.fontMono
                            font.pixelSize: 34
                            font.weight: Font.Bold
                            color: AppTheme.fg
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: BatteryService.statusText
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontBase
                                font.weight: Font.Bold
                                color: AppTheme.fg
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Restante: " + BatteryService.timeRemainingText
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                color: AppTheme.textSecondary
                            }
                        }

                        Text {
                            text: BatteryService.formatPower()
                            font.family: AppTheme.fontMono
                            font.pixelSize: AppTheme.fontLarge
                            font.weight: Font.Bold
                            color: BatteryService.isCharging ? AppTheme.success : AppTheme.warning
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }
                    }

                    MetricBar {
                        fraction: BatteryService.percentage / 100
                        fillColor: BatteryService.levelColor(BatteryService.percentage)
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: AppTheme.paddingSmall

                        StatusPill {
                            icon: String.fromCodePoint(0xf017) // enchufe
                            label: "Fuente"
                            value: BatteryService.powerSource
                            c: BatteryService.onBattery ? AppTheme.warning : AppTheme.success
                        }

                        StatusPill {
                            icon: String.fromCodePoint(0xf0e7) // rayo
                            label: "Potencia"
                            value: BatteryService.formatPower()
                            c: BatteryService.isCharging ? AppTheme.success : AppTheme.warning
                        }

                        StatusPill {
                            icon: String.fromCodePoint(0xf1b2) // pila
                            label: "Energía"
                            value: BatteryService.formatEnergy()
                            c: AppTheme.accent
                        }

                        StatusPill {
                            icon: String.fromCodePoint(0xf2bd) // corazón
                            label: "Salud"
                            // La capacidad real en mAh da el contexto de ese
                            // porcentaje (1739 de 3733 mAh de diseño).
                            value: BatteryService.healthSupported
                                ? BatteryService.healthPercent + "% · "
                                  + BatteryService.chargeFullMah.toFixed(0) + "/"
                                  + BatteryService.chargeDesignMah.toFixed(0) + " mAh"
                                : "no disponible"
                            c: BatteryService.healthColor(BatteryService.healthPercent)
                        }

                        StatusPill {
                            visible: BatteryService.hasBatteryDetail
                            icon: String.fromCodePoint(0xf0e7) // voltaje
                            label: "Tensión"
                            value: BatteryService.voltageVolts.toFixed(2) + " V"
                            c: AppTheme.color6
                        }

                        StatusPill {
                            visible: BatteryService.energyDesignWh > 0
                            icon: String.fromCodePoint(0xf1b2)
                            label: "De diseño"
                            value: BatteryService.energyDesignWh.toFixed(1) + " Wh"
                            c: AppTheme.color8
                        }
                    }
                }
            }

            // ------------------ 4. CARGA Y TEMPERATURAS ---------------------
            SectionLabel { title: "CARGA Y TEMPERATURAS" }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: AppTheme.paddingBase

                // ----------------------------- CPU -----------------------------
                Card {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 300
                    Layout.alignment: Qt.AlignTop

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: AppTheme.paddingBase

                        Text {
                            Layout.fillWidth: true
                            text: "CPU"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                            color: AppTheme.textSecondary
                        }

                        // Frecuencia actual: barra contra el techo del policy0.
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Frecuencia"
                                    font.family: AppTheme.fontLayout
                                    font.pixelSize: AppTheme.fontSmall
                                    color: AppTheme.textSecondary
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: SystemStatsService.cpuFreqMhz > 0
                                        ? SystemStatsService.cpuFreqMhz.toFixed(0) + " MHz"
                                          + (SystemStatsService.cpuMaxMhz > 0
                                             ? " / " + SystemStatsService.cpuMaxMhz.toFixed(0)
                                             : "")
                                        : "—"
                                    font.family: AppTheme.fontMono
                                    font.pixelSize: AppTheme.fontSmall
                                    font.weight: Font.Bold
                                    color: AppTheme.color4
                                }
                            }

                            MetricBar {
                                fraction: SystemStatsService.cpuFreqPercent / 100
                                fillColor: AppTheme.color4
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: SystemStatsService.cpuMinMhz > 0
                                text: "mín " + SystemStatsService.cpuMinMhz.toFixed(0)
                                    + " MHz · " + SystemStatsService.cpuUsage + "% en uso"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontTiny
                                color: AppTheme.textTertiary
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: AppTheme.paddingSmall

                            StatusPill {
                                visible: SystemStatsService.hasEpp
                                icon: String.fromCodePoint(0xf0f3) // EPP
                                label: "EPP"
                                value: SystemStatsService.eppLabel(SystemStatsService.epp)
                                c: SystemStatsService.epp === "power" ? AppTheme.success
                                 : SystemStatsService.epp === "performance" ? AppTheme.warning
                                 : AppTheme.color4
                            }

                            StatusPill {
                                visible: SystemStatsService.hasCpuTemp
                                icon: String.fromCodePoint(0xf2c8) // termómetro
                                label: "CPU"
                                value: SystemStatsService.cpuTemp + "°C"
                                c: SystemStatsService.cpuColor(SystemStatsService.cpuTemp)
                            }
                        }

                        // Heatmap de núcleos (lectura por sensor de coretemp).
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: AppTheme.paddingSmall

                            Text {
                                Layout.fillWidth: true
                                text: "NÚCLEOS"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontTiny
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                                color: AppTheme.textTertiary
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 5
                                columnSpacing: AppTheme.paddingSmall
                                rowSpacing: AppTheme.paddingSmall
                                visible: SystemStatsService.coreTemps.length > 0

                                Repeater {
                                    model: SystemStatsService.coreTemps

                                    delegate: CoreCell {
                                        required property var modelData
                                        coreLabel: modelData.label
                                        temp: modelData.temp
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: SystemStatsService.coreTemps.length === 0
                                text: "Sensores de núcleo no disponibles"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                color: AppTheme.textTertiary
                            }
                        }
                    }
                }

                // ----------------------------- GPU -----------------------------
                Card {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 240
                    Layout.alignment: Qt.AlignTop
                    visible: SystemStatsService.gpuAvailable

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: AppTheme.paddingBase

                        Text {
                            Layout.fillWidth: true
                            text: "GPU"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                            color: AppTheme.textSecondary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: SystemStatsService.gpuName
                            elide: Text.ElideRight
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.textTertiary
                        }

                        MetricBar {
                            fraction: SystemStatsService.gpuUsage / 100
                            fillColor: AppTheme.color13
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: AppTheme.paddingSmall

                            StatusPill {
                                icon: String.fromCodePoint(0xf03e) // carga
                                label: "Uso"
                                value: SystemStatsService.gpuUsage + "%"
                                c: SystemStatsService.usageColor(SystemStatsService.gpuUsage)
                            }

                            StatusPill {
                                icon: String.fromCodePoint(0xf2c8) // temp
                                label: "GPU"
                                value: SystemStatsService.gpuTemp + "°C"
                                c: SystemStatsService.gpuColor(SystemStatsService.gpuTemp)
                            }

                            StatusPill {
                                visible: SystemStatsService.gpuPstate !== ""
                                icon: String.fromCodePoint(0xf0e7)
                                label: "P-State"
                                value: SystemStatsService.gpuPstate
                                c: AppTheme.color13
                            }

                            StatusPill {
                                visible: SystemStatsService.gpuCoreClockMhz > 0
                                icon: String.fromCodePoint(0xf0db) // reloj
                                label: "Reloj"
                                value: SystemStatsService.gpuCoreClockMhz + " MHz"
                                c: AppTheme.color6
                            }

                            StatusPill {
                                visible: SystemStatsService.gpuMemClockMhz > 0
                                icon: String.fromCodePoint(0xf0db)
                                label: "Mem"
                                value: SystemStatsService.gpuMemClockMhz + " MHz"
                                c: AppTheme.color6
                            }

                            StatusPill {
                                visible: SystemStatsService.gpuPowerW > 0
                                icon: String.fromCodePoint(0xf0e7)
                                label: "Consumo"
                                value: SystemStatsService.gpuPowerW.toFixed(1) + " W"
                                c: AppTheme.warning
                            }

                            StatusPill {
                                icon: String.fromCodePoint(0xf538)
                                label: "VRAM"
                                value: SystemStatsService.vramUsedGb.toFixed(1) + " / "
                                    + SystemStatsService.vramTotalGb.toFixed(1) + " GiB"
                                c: SystemStatsService.vramPercent > 90
                                    ? AppTheme.critical : AppTheme.color12
                            }
                        }
                    }
                }
            }

            // Other sensores (NVMe / ACPI / WiFi) como fila de pills.
            Flow {
                Layout.fillWidth: true
                spacing: AppTheme.paddingSmall

                StatusPill {
                    visible: SystemStatsService.hasNvmeTemp
                    icon: String.fromCodePoint(0xf0f7) // disco
                    label: "NVMe"
                    value: SystemStatsService.nvmeTemp + "°C"
                    c: SystemStatsService.statusColor(SystemStatsService.nvmeTemp)
                }

                StatusPill {
                    visible: SystemStatsService.hasNvmeTemp2
                    icon: String.fromCodePoint(0xf0f7)
                    label: "NVMe ctrl."
                    value: SystemStatsService.nvmeTemp2 + "°C"
                    c: SystemStatsService.statusColor(SystemStatsService.nvmeTemp2)
                }

                StatusPill {
                    visible: SystemStatsService.hasLaptopTemp
                    icon: String.fromCodePoint(0xf2c8)
                    label: "ACPI"
                    value: SystemStatsService.laptopTemp + "°C"
                    c: SystemStatsService.statusColor(SystemStatsService.laptopTemp)
                }

                StatusPill {
                    icon: String.fromCodePoint(0xf538)
                    label: "RAM"
                    value: SystemStatsService.memUsage + "%"
                    c: SystemStatsService.memColor(SystemStatsService.memPercent)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(AppTheme.fg, 0.08)
            }

            // --------------------- 5. ESTADO DEL SISTEMA ---------------------
            SectionLabel {
                title: "ESTADO DEL SISTEMA"
                note: BatteryService.gpuMode !== ""
                    ? "GPU: " + BatteryService.gpuMode : ""
            }

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
                    value: (BatteryService.governor || "?")
                        + (BatteryService.turboEnabled ? " · boost ON" : " · boost OFF")
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

            Item { Layout.fillHeight: true }
        }
    }
}