import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

import qs.globals
import qs.services

// widgets/control/NotificationsSection.qml
// Sección de notificaciones en el Panel de Control
Item {
    id: root

    implicitWidth: 800
    implicitHeight: 700

    ColumnLayout {
        anchors.fill: parent
        spacing: AppTheme.paddingLarge

        // ─── Header ───
        RowLayout {
            Layout.fillWidth: true
            spacing: AppTheme.paddingBase

            Text {
                text: "\uf0f3  Notificaciones"
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontLarge
                font.bold: true
                color: AppTheme.fg
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "v1.0"
                font.family: AppTheme.fontMono
                font.pixelSize: AppTheme.fontTiny
                color: AppTheme.textTertiary
            }
        }

        // ─── Do Not Disturb ───
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: dndRow.implicitHeight + AppTheme.paddingBase * 2
            radius: AppTheme.radius
            color: AppTheme.surface
            border.width: 1
            border.color: AppTheme.borderColor

            RowLayout {
                id: dndRow
                anchors.fill: parent
                anchors.margins: AppTheme.paddingBase
                spacing: AppTheme.paddingBase

                Text {
                    text: "\uf1f6"
                    font.family: AppTheme.fontMono
                    font.pixelSize: AppTheme.fontLarge
                    color: NotificationsService.dndEnabled ? AppTheme.critical : AppTheme.textSecondary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: "No Molestar"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontBase
                        font.bold: true
                        color: AppTheme.fg
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: NotificationsService.dndEnabled
                            ? "Silencia notificaciones (excepto críticas)"
                            : "Recibir todas las notificaciones"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: AppTheme.fontSmall
                        color: AppTheme.textSecondary
                    }
                }

                MouseArea {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 32
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationsService.toggleDND()
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: AppTheme.radiusSmall
                        color: NotificationsService.dndEnabled ? AppTheme.critical : AppTheme.surface
                        border.width: 1
                        border.color: NotificationsService.dndEnabled ? AppTheme.critical : AppTheme.borderColor
                        Text {
                            anchors.centerIn: parent
                            text: NotificationsService.dndEnabled ? "ON" : "OFF"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            font.bold: true
                            color: NotificationsService.dndEnabled ? AppTheme.bg : AppTheme.fg
                        }
                    }
                }
            }
        }

        // ─── Configuración ───
        Rectangle {
            Layout.fillWidth: true
            // anchors.fill NO genera tamaño implicito en el padre: sin esto el
            // Rectangle queda en alto 0/1 y su ColumnLayout interior se sale,
            // amontonando los textos uno encima de otro.
            implicitHeight: ajustesCol.implicitHeight + AppTheme.paddingBase * 2
            radius: AppTheme.radius
            color: AppTheme.surface
            border.width: 1
            border.color: AppTheme.borderColor

            ColumnLayout {
                id: ajustesCol
                anchors.fill: parent
                anchors.margins: AppTheme.paddingBase
                spacing: AppTheme.paddingSmall

                // Toggle: Notificaciones habilitadas
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "\uf0f3"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontBase
                        color: AppTheme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        // Sin esto la columna no baja del ancho natural de sus
                        // hijos y los textos se desbordan encima del control de
                        // la derecha (elide nunca llega a activarse).
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            text: "Notificaciones activas"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            color: AppTheme.fg
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "Mostrar toasts emergentes y mantener historial"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.textSecondary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 32
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ControlState.notificationsEnabled = !ControlState.notificationsEnabled
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: AppTheme.radiusSmall
                            color: ControlState.notificationsEnabled ? AppTheme.accent : AppTheme.surface
                            border.width: 1
                            border.color: ControlState.notificationsEnabled ? AppTheme.accent : AppTheme.borderColor
                            Text {
                                anchors.centerIn: parent
                                text: ControlState.notificationsEnabled ? "ON" : "OFF"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                font.bold: true
                                color: ControlState.notificationsEnabled ? AppTheme.bg : AppTheme.fg
                            }
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: AppTheme.borderColor
                    opacity: 0.3
                }

                // Toggle: Toast en monitor activo solo
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "\uf108"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontBase
                        color: AppTheme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        // Sin esto la columna no baja del ancho natural de sus
                        // hijos y los textos se desbordan encima del control de
                        // la derecha (elide nunca llega a activarse).
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            text: "Solo monitor enfocado"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            color: AppTheme.fg
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "Mostrar toasts solo en el monitor con foco (requiere reinicio)"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.textSecondary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    Switch {
                        checked: false
                        enabled: false // TODO: implementar setting
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: AppTheme.borderColor
                    opacity: 0.3
                }

                // Toast max visible
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "\uf080"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontBase
                        color: AppTheme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        // Sin esto la columna no baja del ancho natural de sus
                        // hijos y los textos se desbordan encima del control de
                        // la derecha (elide nunca llega a activarse).
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            text: "Máx. toasts visibles"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            color: AppTheme.fg
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "Número máximo de notificaciones apiladas simultáneamente"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.textSecondary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    SpinBox {
                        Layout.preferredWidth: 80
                        value: AppTheme.notificationsToastMaxVisible
                        from: 1; to: 10; stepSize: 1
                        editable: true
                        onValueChanged: {
                            // TODO: persistir setting
                        }
                    }
                }
            }
        }

        // ─── Historial ───
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: historialCol.implicitHeight + AppTheme.paddingBase * 2
            radius: AppTheme.radius
            color: AppTheme.surface
            border.width: 1
            border.color: AppTheme.borderColor

            ColumnLayout {
                id: historialCol
                anchors.fill: parent
                anchors.margins: AppTheme.paddingBase
                spacing: AppTheme.paddingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "\uf073"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontBase
                        color: AppTheme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        // Sin esto la columna no baja del ancho natural de sus
                        // hijos y los textos se desbordan encima del control de
                        // la derecha (elide nunca llega a activarse).
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            text: "Historial"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            color: AppTheme.fg
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "Límite de notificaciones guardadas al recargar Quickshell"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.textSecondary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    SpinBox {
                        Layout.preferredWidth: 80
                        value: NotificationsService.historyLimit
                        from: 50; to: 500; stepSize: 50
                        editable: true
                        onValueChanged: NotificationsService.historyLimit = value
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: AppTheme.borderColor
                    opacity: 0.3
                }

                // Clear history button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "\uf0c2"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontBase
                        color: AppTheme.critical
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        // Sin esto la columna no baja del ancho natural de sus
                        // hijos y los textos se desbordan encima del control de
                        // la derecha (elide nunca llega a activarse).
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            text: "Limpiar historial"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            color: AppTheme.fg
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "Elimina todas las notificaciones guardadas permanentemente"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.textSecondary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 32
                        cursorShape: Qt.PointingHandCursor
                        enabled: NotificationsService.unreadCount > 0
                        onClicked: NotificationsService.clearHistory()
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: AppTheme.radiusSmall
                            color: enabled ? Qt.alpha(AppTheme.critical, 0.15) : Qt.alpha(AppTheme.surface, 0.5)
                            border.width: 1
                            border.color: enabled ? AppTheme.critical : Qt.alpha(AppTheme.borderColor, 0.5)
                            Text {
                                anchors.centerIn: parent
                                text: "Limpiar"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: AppTheme.fontSmall
                                font.bold: true
                                color: enabled ? AppTheme.critical : AppTheme.textTertiary
                            }
                        }
                    }
                }
            }
        }

        // ─── Estadísticas ───
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: statsCol.implicitHeight + AppTheme.paddingBase * 2
            radius: AppTheme.radius
            color: AppTheme.surface
            border.width: 1
            border.color: AppTheme.borderColor

            ColumnLayout {
                id: statsCol
                anchors.fill: parent
                anchors.margins: AppTheme.paddingBase
                spacing: AppTheme.paddingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "\uf080"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontBase
                        color: AppTheme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        // Sin esto la columna no baja del ancho natural de sus
                        // hijos y los textos se desbordan encima del control de
                        // la derecha (elide nunca llega a activarse).
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            text: "Estadísticas de la sesión"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            color: AppTheme.fg
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "Información desde el último inicio de Quickshell"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.textSecondary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: AppTheme.borderColor
                    opacity: 0.3
                }

                // Grid de stats
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: AppTheme.paddingLarge
                    rowSpacing: AppTheme.paddingBase

                    StatCard { label: "Recibidas"; value: NotificationsService.unreadCount + " (actual)"; icon: "\uf0f3" }
                    StatCard { label: "Límite historial"; value: NotificationsService.historyLimit; icon: "\uf073" }
                    StatCard { label: "DND"; value: NotificationsService.dndEnabled ? "Activo" : "Inactivo"; icon: "\uf1f6" }
                }
            }
        }

        // ─── Atajos ───
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: atajosCol.implicitHeight + AppTheme.paddingBase * 2
            radius: AppTheme.radius
            color: AppTheme.surface
            border.width: 1
            border.color: AppTheme.borderColor

            ColumnLayout {
                id: atajosCol
                anchors.fill: parent
                anchors.margins: AppTheme.paddingBase
                spacing: AppTheme.paddingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: AppTheme.paddingBase

                    Text {
                        text: "\uf11c"
                        font.family: AppTheme.fontMono
                        font.pixelSize: AppTheme.fontBase
                        color: AppTheme.textSecondary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        // Sin esto la columna no baja del ancho natural de sus
                        // hijos y los textos se desbordan encima del control de
                        // la derecha (elide nunca llega a activarse).
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            text: "Atajos de teclado"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontBase
                            color: AppTheme.fg
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "Configurados en Hyprland (SUPER+N por defecto)"
                            font.family: AppTheme.fontLayout
                            font.pixelSize: AppTheme.fontSmall
                            color: AppTheme.textSecondary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: AppTheme.borderColor
                    opacity: 0.3
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // Solo se listan los atajos que existen de verdad. La ventana de centro de
                    // notificaciones se eliminó, así que SUPER+N, "Esc en
                    // centro" y Del/Backspace ya no aplican.
                    KeybindRow { key: "Hover campana"; action: "Ver notificaciones (popup)" }
                    KeybindRow { key: "Click der. campana"; action: "Alternar No Molestar" }
                    KeybindRow { key: "Click mid. campana"; action: "Limpiar historial" }
                    KeybindRow { key: "Rueda en el popup"; action: "Subir/bajar la lista" }
                    KeybindRow { key: "Click ✕ en la notificación"; action: "Quitarla del historial" }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ─── Componentes internos ───

    component StatCard: Rectangle {
        property string label: ""
        property string value: ""
        property string icon: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: AppTheme.radiusSmall
        color: Qt.alpha(AppTheme.fg, 0.03)
        border.width: 1
        border.color: Qt.alpha(AppTheme.fg, 0.05)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: value
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontBase
                font.bold: true
                color: AppTheme.fg
            }
            Text {
                text: label
                font.family: AppTheme.fontLayout
                font.pixelSize: AppTheme.fontTiny
                color: AppTheme.textTertiary
            }
        }
    }

    component KeybindRow: RowLayout {
        property string key: ""
        property string action: ""

        Layout.fillWidth: true
        spacing: AppTheme.paddingBase

        Text {
            text: key
            font.family: AppTheme.fontMono
            font.pixelSize: AppTheme.fontSmall
            color: AppTheme.textSecondary
            Layout.preferredWidth: 160
        }
        Text {
            text: action
            font.family: AppTheme.fontLayout
            font.pixelSize: AppTheme.fontSmall
            color: AppTheme.textTertiary
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}