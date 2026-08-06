// widgets/overview/WindowCard.qml
// Tarjeta que representa una ventana dentro del overview: icono de la app,
// preview en vivo (ScreencopyView) y posicionamiento escalado desde la
// geometría real de la ventana (at/size).
// Adaptado de Shanu-Kumawat/quickshell-overview (modules/overview/OverviewWindow.qml).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.globals
import qs.services

Item {
    id: root

    property var toplevel
    property var windowData
    property var monitorData
    property var widgetMonitorData
    property real scale
    property real availableWorkspaceWidth
    property real availableWorkspaceHeight
    property int widgetMonitorId: 0
    property int recaptureToken: 0
    property real xOffset: 0
    property real yOffset: 0
    property real geometryScaleX: 1
    property real geometryScaleY: 1
    // Capa a la que re-parentamos la tarjeta mientras se arrastra (solo para
    // ventanas special, cuyos tiles están recortados con clip).
    property Item dragLayer
    // Contenedor al que volver tras el arrastre.
    property Item homeParent
    property real homeZ: 0
    property bool animateSize: true
    property bool hovered: false
    property bool pressed: false
    property bool dragInProgress: false
    property bool suspendPositionAnimation: false
    property bool initialized: false

    // Origen de coordenadas: esquina del monitor + barra reservada.
    property real positionBaseX: (monitorData?.x ?? 0) + (monitorData?.reserved?.[0] ?? 0)
    property real positionBaseY: (monitorData?.y ?? 0) + (monitorData?.reserved?.[1] ?? 0)

    // Corrección de proporción cuando el monitor está rotado o escalado.
    readonly property real widthRatio: {
        if (!widgetMonitorData || !monitorData)
            return 1;
        const widgetWidth = (widgetMonitorData.transform % 2 === 1) ? (widgetMonitorData.height ?? 1) : (widgetMonitorData.width ?? 1);
        const sourceWidth = (monitorData.transform % 2 === 1) ? (monitorData.height ?? 1) : (monitorData.width ?? 1);
        const sourceScale = monitorData.scale ?? 1;
        const widgetScale = widgetMonitorData.scale ?? 1;
        return (widgetWidth * sourceScale) / (sourceWidth * widgetScale);
    }
    readonly property real heightRatio: {
        if (!widgetMonitorData || !monitorData)
            return 1;
        const widgetHeight = (widgetMonitorData.transform % 2 === 1) ? (widgetMonitorData.width ?? 1) : (widgetMonitorData.height ?? 1);
        const sourceHeight = (monitorData.transform % 2 === 1) ? (monitorData.width ?? 1) : (monitorData.height ?? 1);
        const sourceScale = monitorData.scale ?? 1;
        const widgetScale = widgetMonitorData.scale ?? 1;
        return (widgetHeight * sourceScale) / (sourceHeight * widgetScale);
    }

    readonly property real initX: Math.max(((windowData?.at[0] ?? 0) - root.positionBaseX) * root.scale * geometryScaleX, 0) + xOffset
    readonly property real initY: Math.max(((windowData?.at[1] ?? 0) - root.positionBaseY) * root.scale * geometryScaleY, 0) + yOffset
    readonly property real targetWindowWidth: (windowData?.size[0] ?? 100) * root.scale * geometryScaleX
    readonly property real targetWindowHeight: (windowData?.size[1] ?? 100) * root.scale * geometryScaleY

    readonly property bool previewsEnabled: AppTheme.overviewPreviewsEnabled
    readonly property string previewMode: {
        const mode = `${AppTheme.overviewPreviewMode ?? "live"}`.trim().toLowerCase();
        return (mode === "event" || mode === "snapshot") ? "event" : "live";
    }
    readonly property bool livePreviewEnabled: previewsEnabled && previewMode === "live"

    // Solo capturamos ventanas del monitor del widget y mientras el overview está abierto.
    readonly property bool shouldCapturePreview: {
        if (!OverviewService.overviewOpen || !root.previewsEnabled || !root.toplevel)
            return false;
        return (windowData?.monitor ?? -1) === widgetMonitorId;
    }

    // Icono de la aplicación desde su .desktop (por class).
    readonly property var entry: {
        DesktopEntries.applications.values; // re-run cuando cambia el índice de aplicaciones
        return DesktopEntries.heuristicLookup(windowData?.class);
    }
    readonly property string iconName: {
        const raw = `${entry?.icon ?? ""}`.trim();
        const withoutProviderPrefix = raw.replace(/^image:\/\/icon\//, "");
        const withoutQuery = withoutProviderPrefix.split("?")[0].trim();
        return withoutQuery.length > 0 ? withoutQuery : "application-x-executable";
    }
    readonly property var iconPath: Quickshell.iconPath(iconName, "image-missing")
    readonly property real iconSize: Math.min(root.width, root.height) * AppTheme.overviewIconToWindowRatio / (root.monitorData?.scale ?? 1)

    readonly property real srcAspect: {
        const w = root.windowData?.size?.[0] ?? 0;
        const h = root.windowData?.size?.[1] ?? 0;
        return (w > 0 && h > 0) ? (w / h) : 1;
    }

    x: initX
    y: initY
    width: Math.min(targetWindowWidth, availableWorkspaceWidth)
    height: Math.min(targetWindowHeight, availableWorkspaceHeight)

    // Ocultamos la tarjeta si en su workspace hay una ventana fullscreen.
    visible: {
        const thisWsId = windowData?.workspace?.id;
        const isFullscreen = (windowData?.fullscreen ?? 0) > 0;
        if (isFullscreen || thisWsId === undefined) return true;
        return !HyprlandData.windowList.some(w => w.workspace?.id === thisWsId && (w.fullscreen ?? 0) > 0);
    }

    clip: true
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    Behavior on x {
        enabled: root.initialized && !root.dragInProgress && !root.suspendPositionAnimation
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: root.initialized && !root.dragInProgress && !root.suspendPositionAnimation
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on width {
        enabled: root.initialized && root.animateSize && !root.dragInProgress && !root.suspendPositionAnimation
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        enabled: root.initialized && root.animateSize && !root.dragInProgress && !root.suspendPositionAnimation
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // Fondo opaco de la tarjeta para que no se transparente el blur de detrás.
    Rectangle {
        visible: (root.windowData?.monitor ?? -1) === root.widgetMonitorId
        anchors.fill: parent
        radius: AppTheme.radiusLarge * root.scale
        color: Qt.alpha(AppTheme.color0, 0.92)
    }

    ScreencopyView {
        id: windowPreview
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height * root.srcAspect)
        height: Math.min(parent.height, parent.width / root.srcAspect)
        captureSource: root.shouldCapturePreview ? root.toplevel : null
        live: root.livePreviewEnabled
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: previewMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    // Overlay de estado (hover/pressed) y borde de acento.
    Rectangle {
        anchors.fill: parent
        radius: AppTheme.radiusLarge * root.scale
        color: root.pressed
            ? Qt.alpha(AppTheme.fg, 0.16)
            : root.hovered
                ? Qt.alpha(AppTheme.fg, 0.10)
                : "transparent"
        border.width: root.hovered ? 1 : 0
        border.color: AppTheme.color4
    }

    // Icono de la aplicación centrado (sobre el preview).
    Image {
        anchors.centerIn: parent
        visible: root.iconSize > 1
        source: root.iconPath
        width: root.iconSize
        height: root.iconSize
        sourceSize: Qt.size(Math.max(1, Math.round(root.iconSize)), Math.max(1, Math.round(root.iconSize)))
    }

    // Máscara con el radio de la tarjeta para recortar el preview.
    Item {
        id: previewMask
        width: windowPreview.width
        height: windowPreview.height
        anchors.centerIn: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        Rectangle {
            anchors.centerIn: parent
            width: root.width
            height: root.height
            radius: AppTheme.radiusLarge * root.scale
        }
    }

    // Reparenting al layer de arrastre (solo para ventanas special).
    function moveToDragLayer() {
        if (!root.dragLayer) return;
        const mapped = root.mapToItem(root.dragLayer, 0, 0);
        root.suspendPositionAnimation = true;
        root.parent = root.dragLayer;
        root.x = mapped.x;
        root.y = mapped.y;
        root.z = root.dragLayer.z + 1;
        Qt.callLater(() => root.suspendPositionAnimation = false);
    }

    function returnToHomeParent() {
        if (!root.homeParent) return;
        root.suspendPositionAnimation = true;
        root.parent = root.homeParent;
        root.z = root.homeZ;
        Qt.callLater(() => root.suspendPositionAnimation = false);
    }

    property bool previewCaptureEnabled: true

    // En modo "event" recapturamos las previews cuando cambian las ventanas.
    function refreshCapture() {
        if (!OverviewService.overviewOpen || root.livePreviewEnabled || !root.previewsEnabled)
            return;
        root.previewCaptureEnabled = false;
        previewResetTimer.restart();
    }

    Timer {
        id: previewResetTimer
        interval: AppTheme.overviewPreviewRecaptureDelayMs
        repeat: false
        onTriggered: root.previewCaptureEnabled = true
    }

    onRecaptureTokenChanged: {
        if (recaptureToken > 0)
            root.refreshCapture();
    }
}
