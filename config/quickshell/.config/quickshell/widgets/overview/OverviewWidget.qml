// widgets/overview/OverviewWidget.qml
// Contenido del workspace overview: grid de workspaces con las ventanas encima,
// franja de special workspaces, indicador del workspace activo y drag & drop.
// Adaptado de Shanu-Kumawat/quickshell-overview (modules/overview/OverviewWidget.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.globals
import qs.services
import qs.widgets.overview

Item {
    id: root
    required property var panelWindow
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int effectiveActiveWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id ?? 1))
    readonly property int workspacesShown: AppTheme.overviewRows * AppTheme.overviewColumns
    // Grupo de workspaces visible: arranca en el workspace activo (10 visibles).
    readonly property int workspaceGroup: Math.floor((effectiveActiveWorkspaceId - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property var windowByAddress: HyprlandData.windowByAddress
    property var workspaceIds: HyprlandData.workspaceIds
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: AppTheme.overviewScale
    property color activeBorderColor: AppTheme.color4

    // Tamaño escalado de cada workspace (monitor menos barras reservadas).
    readonly property real workspaceImplicitWidth: Math.round((monitorData?.transform % 2 === 1) ?
        ((monitor.height / monitor.scale - (monitorData?.reserved?.[0] ?? 0) - (monitorData?.reserved?.[2] ?? 0)) * root.scale) :
        ((monitor.width / monitor.scale - (monitorData?.reserved?.[0] ?? 0) - (monitorData?.reserved?.[2] ?? 0)) * root.scale))
    readonly property real workspaceImplicitHeight: Math.round((monitorData?.transform % 2 === 1) ?
        ((monitor.width / monitor.scale - (monitorData?.reserved?.[1] ?? 0) - (monitorData?.reserved?.[3] ?? 0)) * root.scale) :
        ((monitor.height / monitor.scale - (monitorData?.reserved?.[1] ?? 0) - (monitorData?.reserved?.[3] ?? 0)) * root.scale))

    readonly property real workspaceNumberSize: AppTheme.overviewWorkspaceNumberBaseSize * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: AppTheme.overviewSpacing
    property bool showSpecialWorkspaces: AppTheme.overviewShowSpecialWorkspaces
    property int specialWorkspaceColumns: Math.max(1, AppTheme.overviewSpecialColumns)
    property real panelOpacity: Math.max(0, Math.min(1, AppTheme.overviewPanelOpacity))
    property real workspaceOpacity: Math.max(0, Math.min(1, AppTheme.overviewWorkspaceOpacity))
    property bool previewsEnabled: AppTheme.overviewPreviewsEnabled
    property int previewRecaptureToken: 0

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingTargetSpecialWorkspace: ""

    readonly property var allWorkspaces: HyprlandData.allWorkspaces

    // ───── Special workspaces ─────
    readonly property var monitorSpecialWorkspaceNames: {
        const names = [];
        for (const ws of (allWorkspaces ?? [])) {
            const name = `${ws?.name ?? ""}`;
            if (!name.startsWith("special:")) continue;
            if (`${ws?.monitor ?? ""}` !== `${root.monitor?.name ?? ""}`) continue;
            names.push(name.slice(8));
        }
        return names;
    }

    readonly property var specialWorkspaceNamesFromWindows: {
        const names = [];
        for (const addr in windowByAddress) {
            const win = windowByAddress[addr];
            if ((win?.monitor ?? -1) !== (root.monitor?.id ?? -1)) continue;
            const wsName = `${win?.workspace?.name ?? ""}`;
            if (!wsName.startsWith("special:")) continue;
            names.push(wsName.slice(8));
        }
        return names;
    }

    readonly property var visibleSpecialWorkspaces: {
        if (!showSpecialWorkspaces) return [];
        const out = [];
        const pushUnique = (value) => {
            const cleaned = `${value ?? ""}`.trim();
            if (cleaned.length === 0 || out.includes(cleaned)) return;
            out.push(cleaned);
        };
        // El scratchpad configurado ("magic") siempre aparece, aunque esté vacío.
        for (const ws of WorkspacesService.visibleWorkspaces)
            if (ws === "special") pushUnique("magic");
        for (const name of monitorSpecialWorkspaceNames) pushUnique(name);
        for (const name of specialWorkspaceNamesFromWindows) pushUnique(name);
        return out;
    }

    readonly property bool hasSpecialWorkspaceSection: visibleSpecialWorkspaces.length > 0
    readonly property string createSpecialWorkspaceTarget: "__create_special_workspace__"
    readonly property real specialWorkspaceTileHeight: root.workspaceImplicitHeight
    readonly property real specialStripGap: workspaceSpacing * 1.8
    readonly property real specialStripPadding: Math.max(8, 12 * root.scale)
    readonly property real specialStripTitleHeight: Math.max(14, AppTheme.fontSmall * root.scale)
    readonly property real specialStripTitleGap: Math.max(6, 8 * root.scale)
    readonly property int totalSpecialTiles: visibleSpecialWorkspaces.length + 1
    readonly property real specialSectionWidth: workspaceColumnLayout.implicitWidth
    readonly property real specialGridInnerWidth: Math.max(0, root.specialSectionWidth - root.specialStripPadding * 2)
    readonly property int effectiveSpecialColumns: Math.max(1, Math.min(root.specialWorkspaceColumns, root.totalSpecialTiles))
    readonly property int specialWorkspaceRows: Math.ceil(root.totalSpecialTiles / root.effectiveSpecialColumns)
    readonly property real specialWorkspaceAspectCap: {
        let maxAspect = Math.max(1, root.workspaceImplicitWidth / Math.max(1, root.workspaceImplicitHeight));
        for (const name of visibleSpecialWorkspaces) {
            const geometry = root.specialWorkspaceGeometry(name, root.monitor?.id);
            const width = geometry?.width;
            const height = geometry?.height;
            if (!Number.isFinite(width) || !Number.isFinite(height) || height <= 0) continue;
            maxAspect = Math.max(maxAspect, width / height);
        }
        return maxAspect;
    }
    readonly property real specialWorkspaceTileWidth: {
        const gaps = Math.max(0, root.effectiveSpecialColumns - 1);
        const rawWidth = (root.specialGridInnerWidth - gaps * workspaceSpacing) / root.effectiveSpecialColumns;
        const aspectWidth = root.specialWorkspaceTileHeight * root.specialWorkspaceAspectCap;
        const cappedWidth = Math.min(rawWidth, aspectWidth);
        return Math.max(80 * root.scale, cappedWidth);
    }
    readonly property real specialGridUsedWidth: root.effectiveSpecialColumns * root.specialWorkspaceTileWidth + Math.max(0, root.effectiveSpecialColumns - 1) * workspaceSpacing
    readonly property real specialGridOffsetX: root.specialStripPadding + Math.max(0, (root.specialGridInnerWidth - root.specialGridUsedWidth) / 2)
    readonly property real specialGridHeight: root.specialWorkspaceRows * root.specialWorkspaceTileHeight + Math.max(0, root.specialWorkspaceRows - 1) * workspaceSpacing
    readonly property real specialStripHeight: root.specialStripPadding * 2 + root.specialStripTitleHeight + root.specialStripTitleGap + root.specialGridHeight

    // ───── Geometría del grid ─────
    function getWorkspaceRow(workspaceId) {
        if (!Number.isFinite(workspaceId)) return 0;
        return Math.floor((workspaceId - 1) / AppTheme.overviewColumns) % AppTheme.overviewRows;
    }

    function getWorkspaceColumn(workspaceId) {
        if (!Number.isFinite(workspaceId)) return 0;
        return (workspaceId - 1) % AppTheme.overviewColumns;
    }

    function getWorkspaceInCell(rowIndex, colIndex) {
        return (root.workspaceGroup * root.workspacesShown) + (rowIndex * AppTheme.overviewColumns) + colIndex + 1;
    }

    function getVisibleRowPosition(rowIndex) {
        if (!Number.isFinite(rowIndex) || rowIndex < 0) return 0;
        if (!AppTheme.overviewHideEmptyRows || !(rowsWithContent instanceof Set)) return rowIndex;
        let visibleRow = 0;
        for (let i = 0; i < rowIndex; i += 1) {
            if (rowsWithContent.has(i)) visibleRow += 1;
        }
        return visibleRow;
    }

    function stepWorkspace(delta) {
        if (!Number.isFinite(delta) || delta === 0) return;
        const currentId = monitor?.activeWorkspace?.id ?? effectiveActiveWorkspaceId;
        const minWorkspaceId = 1;
        let maxWorkspaceId = minWorkspaceId + root.workspacesShown - 1;
        for (const workspaceId of (workspaceIds ?? [])) {
            if (Number.isFinite(workspaceId) && workspaceId >= minWorkspaceId) {
                maxWorkspaceId = Math.max(maxWorkspaceId, workspaceId);
            }
        }
        maxWorkspaceId = Math.max(maxWorkspaceId, currentId);
        let targetId = currentId + delta;
        if (targetId < minWorkspaceId) {
            targetId = maxWorkspaceId;
        } else if (targetId > maxWorkspaceId) {
            targetId = minWorkspaceId;
        }
        OverviewService.focusWorkspace(targetId);
    }

    function isSpecialWorkspace(windowData) {
        const wsName = `${windowData?.workspace?.name ?? ""}`;
        return wsName.startsWith("special:");
    }

    function specialWorkspaceName(windowData) {
        const wsName = `${windowData?.workspace?.name ?? ""}`;
        return wsName.startsWith("special:") ? wsName.slice(8) : "";
    }

    function nextSpecialWorkspaceName() {
        const taken = new Set();
        for (const name of visibleSpecialWorkspaces)
            taken.add(`${name ?? ""}`.trim().toLowerCase());
        const base = "stash";
        if (!taken.has(base)) return base;
        let index = 2;
        while (taken.has(`${base}-${index}`)) index += 1;
        return `${base}-${index}`;
    }

    // Orden de apilado: pinned > floating > foco reciente.
    function specialWindowZ(win) {
        const pinned = win?.pinned ? 200000 : 0;
        const floating = win?.floating ? 100000 : 0;
        const focus = 10000 - (win?.focusHistoryID ?? 9999);
        return pinned + floating + focus;
    }

    // Caja que agrupa las ventanas de un special workspace (para ajustar la escala).
    function specialWorkspaceGeometry(name, monitorId) {
        const trimmedName = `${name ?? ""}`.trim();
        const currentMonitorId = monitorId ?? -1;
        let minX = null, minY = null, maxX = null, maxY = null;
        for (const addr in windowByAddress) {
            const win = windowByAddress[addr];
            if ((win?.monitor ?? -1) !== currentMonitorId) continue;
            if (root.specialWorkspaceName(win) !== trimmedName) continue;
            const atX = win?.at?.[0];
            const atY = win?.at?.[1];
            const width = win?.size?.[0];
            const height = win?.size?.[1];
            if (!Number.isFinite(atX) || !Number.isFinite(atY)) continue;
            if (!Number.isFinite(width) || !Number.isFinite(height)) continue;
            minX = minX === null ? atX : Math.min(minX, atX);
            minY = minY === null ? atY : Math.min(minY, atY);
            maxX = maxX === null ? (atX + width) : Math.max(maxX, atX + width);
            maxY = maxY === null ? (atY + height) : Math.max(maxY, atY + height);
        }
        return {
            x: minX,
            y: minY,
            width: (minX !== null && maxX !== null) ? Math.max(1, maxX - minX) : null,
            height: (minY !== null && maxY !== null) ? Math.max(1, maxY - minY) : null
        };
    }

    // Filas con contenido (workspace activo o con ventanas) para ocultar las vacías.
    property var rowsWithContent: {
        if (!AppTheme.overviewHideEmptyRows) return null;
        const rows = new Set();
        const firstWorkspace = root.workspaceGroup * root.workspacesShown + 1;
        const lastWorkspace = (root.workspaceGroup + 1) * root.workspacesShown;
        const currentWorkspace = effectiveActiveWorkspaceId;
        if (currentWorkspace >= firstWorkspace && currentWorkspace <= lastWorkspace) {
            rows.add(root.getWorkspaceRow(currentWorkspace));
        }
        for (const addr in windowByAddress) {
            const win = windowByAddress[addr];
            const wsId = win?.workspace?.id;
            if (wsId >= firstWorkspace && wsId <= lastWorkspace) {
                rows.add(root.getWorkspaceRow(wsId));
            }
        }
        return rows;
    }

    implicitWidth: overviewBackground.implicitWidth + AppTheme.paddingBase * 2
    implicitHeight: overviewBackground.implicitHeight + AppTheme.paddingBase * 2

    // En modo "event" pedimos recapturar las previews cuando cambian las ventanas.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!OverviewService.overviewOpen || !root.previewsEnabled)
                return;
            if (AppTheme.overviewPreviewMode !== "event")
                return;
            const eventName = `${event?.name ?? event?.event ?? event?.type ?? ""}`;
            if (["closewindow", "openwindow", "movewindow"].includes(eventName)) {
                root.previewRecaptureToken += 1;
            }
        }
    }

    Rectangle { // Panel
        id: overviewBackground
        property real padding: AppTheme.overviewPanelPadding
        anchors.fill: parent
        anchors.margins: AppTheme.paddingBase

        implicitWidth: contentLayout.implicitWidth + padding * 2
        implicitHeight: contentLayout.implicitHeight + padding * 2
        radius: AppTheme.radiusLarge * root.scale + padding
        clip: true
        color: Qt.alpha(AppTheme.bg, root.panelOpacity)
        border.width: 1
        border.color: Qt.alpha(AppTheme.fg, 0.12)

        // Evita que los clicks sobre el panel lleguen al outsideClickCatcher.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: (mouse) => mouse.accepted = true
        }

        ColumnLayout { // Workspaces
            id: contentLayout
            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: root.workspaceSpacing

            ColumnLayout {
                id: workspaceColumnLayout
                spacing: root.workspaceSpacing

                Repeater {
                    model: AppTheme.overviewRows
                    delegate: RowLayout {
                        id: row
                        property int rowIndex: index
                        spacing: root.workspaceSpacing
                        visible: !AppTheme.overviewHideEmptyRows ||
                                 (root.rowsWithContent && root.rowsWithContent.has(rowIndex))
                        height: visible ? implicitHeight : 0

                        Repeater { // Workspace
                            model: AppTheme.overviewColumns
                            delegate: Rectangle {
                                id: workspace
                                property int colIndex: index
                                property int workspaceValue: root.getWorkspaceInCell(rowIndex, colIndex)
                                property bool hoveredWhileDragging: false
                                property color defaultWorkspaceColor: Qt.lighter(AppTheme.bg, 1.12)
                                property color hoveredWorkspaceColor: Qt.lighter(AppTheme.bg, 1.3)

                                implicitWidth: root.workspaceImplicitWidth
                                implicitHeight: root.workspaceImplicitHeight
                                color: Qt.alpha(hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor, root.workspaceOpacity)
                                radius: AppTheme.radiusLarge * root.scale
                                border.width: 2
                                border.color: hoveredWhileDragging ? Qt.alpha(root.activeBorderColor, 0.9) : "transparent"

                                Text { // Número del workspace
                                    anchors.centerIn: parent
                                    text: workspaceValue
                                    font.pixelSize: root.workspaceNumberSize * root.scale
                                    font.family: AppTheme.fontLayout
                                    font.weight: Font.DemiBold
                                    color: Qt.alpha(AppTheme.fg, 0.35)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        if (root.draggingTargetWorkspace === -1) {
                                            OverviewService.close()
                                            OverviewService.focusWorkspace(workspaceValue)
                                        }
                                    }
                                }

                                DropArea {
                                    anchors.fill: parent
                                    onEntered: {
                                        root.draggingTargetWorkspace = workspaceValue
                                        root.draggingTargetSpecialWorkspace = ""
                                        if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                                        hoveredWhileDragging = true
                                    }
                                    onExited: {
                                        hoveredWhileDragging = false
                                        if (root.draggingTargetWorkspace == workspaceValue) root.draggingTargetWorkspace = -1
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                visible: root.showSpecialWorkspaces
                implicitWidth: 1
                implicitHeight: root.specialStripGap
            }

            Item { // Franja de special workspaces
                id: specialWorkspaceSection
                visible: root.showSpecialWorkspaces
                implicitWidth: root.specialSectionWidth
                implicitHeight: root.specialStripHeight

                Rectangle {
                    anchors.fill: parent
                    radius: AppTheme.radiusLarge * root.scale
                    color: Qt.alpha(Qt.lighter(AppTheme.bg, 1.06), root.workspaceOpacity)
                    border.width: 1
                    border.color: Qt.alpha(AppTheme.fg, 0.1)

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: root.specialStripPadding
                        anchors.topMargin: root.specialStripPadding
                        text: "Special Workspaces"
                        font.family: AppTheme.fontLayout
                        font.pixelSize: root.specialStripTitleHeight
                        font.weight: Font.DemiBold
                        color: Qt.alpha(AppTheme.fg, 0.8)
                    }

                    Grid {
                        id: specialWorkspaceGrid
                        x: root.specialGridOffsetX
                        y: root.specialStripPadding + root.specialStripTitleHeight + root.specialStripTitleGap
                        width: root.specialGridUsedWidth
                        columns: root.effectiveSpecialColumns
                        rowSpacing: root.workspaceSpacing
                        columnSpacing: root.workspaceSpacing

                        Repeater {
                            model: root.visibleSpecialWorkspaces
                            delegate: Rectangle {
                                id: specialWorkspaceTile
                                required property string modelData
                                property string specialName: modelData
                                property var specialGeometry: root.specialWorkspaceGeometry(specialName, root.monitor?.id)
                                property bool hasRenderableGeometry: Number.isFinite(specialGeometry?.width)
                                    && Number.isFinite(specialGeometry?.height)
                                    && specialGeometry.width > 0
                                    && specialGeometry.height > 0
                                property real geometryWidth: hasRenderableGeometry ? specialGeometry.width : Math.max(1, root.workspaceImplicitWidth / root.scale)
                                property real geometryHeight: hasRenderableGeometry ? specialGeometry.height : Math.max(1, root.workspaceImplicitHeight / root.scale)
                                property real fitScale: hasRenderableGeometry ? Math.min(width / geometryWidth, height / geometryHeight) : root.scale
                                property real contentWidth: hasRenderableGeometry ? (geometryWidth * fitScale) : width
                                property real contentHeight: hasRenderableGeometry ? (geometryHeight * fitScale) : height
                                property real contentOffsetX: Math.max(0, (width - contentWidth) / 2)
                                property real contentOffsetY: Math.max(0, (height - contentHeight) / 2)
                                implicitWidth: root.specialWorkspaceTileWidth
                                implicitHeight: root.specialWorkspaceTileHeight
                                radius: AppTheme.radiusLarge * root.scale
                                clip: true
                                color: Qt.alpha(Qt.lighter(AppTheme.bg, 1.18), root.workspaceOpacity)
                                border.width: 1
                                border.color: Qt.alpha(AppTheme.fg, 0.12)

                                Text {
                                    anchors.centerIn: parent
                                    visible: !specialWorkspaceTile.hasRenderableGeometry
                                    text: specialWorkspaceTile.specialName
                                    font.family: AppTheme.fontLayout
                                    font.pixelSize: root.workspaceNumberSize * root.scale * 0.5
                                    font.weight: Font.DemiBold
                                    color: Qt.alpha(AppTheme.fg, 0.5)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        if (root.draggingTargetWorkspace === -1 && !root.draggingTargetSpecialWorkspace) {
                                            OverviewService.close()
                                            OverviewService.toggleSpecial(specialWorkspaceTile.specialName)
                                        }
                                    }
                                }

                                DropArea {
                                    anchors.fill: parent
                                    onEntered: {
                                        root.draggingTargetWorkspace = -1
                                        root.draggingTargetSpecialWorkspace = specialWorkspaceTile.specialName
                                    }
                                    onExited: {
                                        if (root.draggingTargetSpecialWorkspace === specialWorkspaceTile.specialName)
                                            root.draggingTargetSpecialWorkspace = ""
                                    }
                                }

                                Item { // Contenido del special workspace (ventanas escaladas)
                                    id: specialWorkspaceContent
                                    x: specialWorkspaceTile.contentOffsetX
                                    y: specialWorkspaceTile.contentOffsetY
                                    width: specialWorkspaceTile.contentWidth
                                    height: specialWorkspaceTile.contentHeight
                                    clip: true

                                    Repeater {
                                        model: ScriptModel {
                                            values: {
                                                if (!specialWorkspaceTile.hasRenderableGeometry) return [];
                                                return ToplevelManager.toplevels.values.filter((toplevel) => {
                                                    const address = `0x${toplevel.HyprlandToplevel.address}`;
                                                    const win = windowByAddress[address];
                                                    if ((win?.monitor ?? -1) !== (root.monitor?.id ?? -1)) return false;
                                                    return root.specialWorkspaceName(win) === specialWorkspaceTile.specialName;
                                                }).sort((a, b) => {
                                                    const addrA = `0x${a.HyprlandToplevel.address}`;
                                                    const addrB = `0x${b.HyprlandToplevel.address}`;
                                                    return addrA.localeCompare(addrB);
                                                });
                                            }
                                        }
                                        delegate: WindowCard {
                                            id: specialWindow
                                            required property var modelData
                                            required property int index
                                            property var address: `0x${modelData.HyprlandToplevel.address}`
                                            property int monitorId: windowData?.monitor
                                            property var monitor: HyprlandData.monitors.find(m => m.id === monitorId)
                                            windowData: windowByAddress[address]
                                            toplevel: modelData
                                            monitorData: monitor
                                            widgetMonitorData: root.monitorData
                                            scale: root.scale
                                            availableWorkspaceWidth: specialWorkspaceContent.width
                                            availableWorkspaceHeight: specialWorkspaceContent.height
                                            positionBaseX: Number.isFinite(specialWorkspaceTile.specialGeometry?.x)
                                                ? specialWorkspaceTile.specialGeometry.x
                                                : ((monitor?.x ?? 0) + (monitor?.reserved?.[0] ?? 0))
                                            positionBaseY: Number.isFinite(specialWorkspaceTile.specialGeometry?.y)
                                                ? specialWorkspaceTile.specialGeometry.y
                                                : ((monitor?.y ?? 0) + (monitor?.reserved?.[1] ?? 0))
                                            geometryScaleX: specialWorkspaceTile.fitScale / root.scale
                                            geometryScaleY: specialWorkspaceTile.fitScale / root.scale
                                            xOffset: 0
                                            yOffset: 0
                                            widgetMonitorId: root.monitor.id
                                            recaptureToken: root.previewRecaptureToken
                                            animateSize: false
                                            z: root.specialWindowZ(windowData)
                                            dragLayer: specialWindowDragLayer
                                            homeParent: specialWorkspaceContent
                                            homeZ: root.specialWindowZ(windowData)

                                            MouseArea {
                                                id: specialDragArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: hovered = true
                                                onExited: hovered = false
                                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                                drag.target: parent
                                                onPressed: (mouse) => {
                                                    root.draggingFromWorkspace = -1
                                                    root.draggingTargetSpecialWorkspace = ""
                                                    specialWindow.pressed = true
                                                    specialWindow.dragInProgress = true
                                                    specialWindow.Drag.source = specialWindow
                                                    specialWindow.Drag.hotSpot.x = mouse.x
                                                    specialWindow.Drag.hotSpot.y = mouse.y
                                                    specialWindow.moveToDragLayer()
                                                    specialWindow.Drag.active = true
                                                }
                                                onReleased: {
                                                    const targetWorkspace = root.draggingTargetWorkspace
                                                    const targetSpecialWorkspace = root.draggingTargetSpecialWorkspace
                                                    specialWindow.pressed = false
                                                    specialWindow.Drag.active = false
                                                    specialWindow.dragInProgress = false
                                                    root.draggingFromWorkspace = -1
                                                    root.draggingTargetWorkspace = -1
                                                    root.draggingTargetSpecialWorkspace = ""
                                                    if (targetSpecialWorkspace === root.createSpecialWorkspaceTarget) {
                                                        const createdName = root.nextSpecialWorkspaceName()
                                                        OverviewService.moveToSpecial(specialWindow.windowData?.address, createdName)
                                                        specialWindow.returnToHomeParent()
                                                        specialWindow.x = specialWindow.initX
                                                        specialWindow.y = specialWindow.initY
                                                    } else if (targetSpecialWorkspace && targetSpecialWorkspace !== specialWorkspaceTile.specialName) {
                                                        OverviewService.moveToSpecial(specialWindow.windowData?.address, targetSpecialWorkspace)
                                                        specialWindow.returnToHomeParent()
                                                        specialWindow.x = specialWindow.initX
                                                        specialWindow.y = specialWindow.initY
                                                    } else if (targetWorkspace !== -1) {
                                                        OverviewService.moveToWorkspace(specialWindow.windowData?.address, targetWorkspace)
                                                        specialWindow.returnToHomeParent()
                                                        specialWindow.x = specialWindow.initX
                                                        specialWindow.y = specialWindow.initY
                                                    } else {
                                                        specialWindow.returnToHomeParent()
                                                        specialWindow.x = specialWindow.initX
                                                        specialWindow.y = specialWindow.initY
                                                    }
                                                }
                                                onClicked: (event) => {
                                                    if (!specialWindow.windowData) return;
                                                    if (event.button === Qt.LeftButton) {
                                                        OverviewService.close()
                                                        OverviewService.focusWindow(specialWindow.windowData.address)
                                                        event.accepted = true
                                                    } else if (event.button === Qt.MiddleButton) {
                                                        OverviewService.closeWindow(specialWindow.windowData.address)
                                                        event.accepted = true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle { // Crear un special workspace nuevo
                            id: createSpecialWorkspaceTile
                            implicitWidth: root.specialWorkspaceTileWidth
                            implicitHeight: root.specialWorkspaceTileHeight
                            radius: AppTheme.radiusLarge * root.scale
                            color: root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget
                                ? Qt.alpha(root.activeBorderColor, 0.5)
                                : Qt.alpha(Qt.lighter(AppTheme.bg, 1.18), root.workspaceOpacity)
                            border.width: 1
                            border.color: root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget
                                ? Qt.alpha(root.activeBorderColor, 0.96)
                                : Qt.alpha(AppTheme.color4, 0.4)

                            Text {
                                anchors.centerIn: parent
                                text: root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget ? "Release" : "+"
                                font.family: AppTheme.fontLayout
                                font.pixelSize: root.workspaceNumberSize * root.scale
                                font.weight: Font.DemiBold
                                color: Qt.alpha(AppTheme.fg, 0.92)
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    const createdName = root.nextSpecialWorkspaceName()
                                    OverviewService.close()
                                    OverviewService.toggleSpecial(createdName)
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: {
                                    root.draggingTargetWorkspace = -1
                                    root.draggingTargetSpecialWorkspace = root.createSpecialWorkspaceTarget
                                }
                                onExited: {
                                    if (root.draggingTargetSpecialWorkspace === root.createSpecialWorkspaceTarget)
                                        root.draggingTargetSpecialWorkspace = ""
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { // Ventanas e indicador del workspace activo
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: contentLayout.implicitWidth
            implicitHeight: contentLayout.implicitHeight

            // Cambiar de workspace con la rueda del ratón.
            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    const deltaY = event.angleDelta.y;
                    if (!deltaY) return;
                    root.stepWorkspace(deltaY > 0 ? -1 : 1);
                    event.accepted = true;
                }
            }

            Repeater { // Ventanas normales del grupo visible
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel.address}`;
                            const win = windowByAddress[address];
                            if (root.isSpecialWorkspace(win)) return false;
                            const minWorkspace = root.workspaceGroup * root.workspacesShown + 1;
                            const maxWorkspace = (root.workspaceGroup + 1) * root.workspacesShown;
                            return (minWorkspace <= win?.workspace?.id && win?.workspace?.id <= maxWorkspace);
                        }).sort((a, b) => {
                            // Mismo orden de apilado que Hyprland.
                            const addrA = `0x${a.HyprlandToplevel.address}`;
                            const addrB = `0x${b.HyprlandToplevel.address}`;
                            const winA = windowByAddress[addrA];
                            const winB = windowByAddress[addrB];
                            if (winA?.pinned !== winB?.pinned) return winA?.pinned ? 1 : -1;
                            if (winA?.floating !== winB?.floating) return winA?.floating ? 1 : -1;
                            return (winB?.focusHistoryID ?? 0) - (winA?.focusHistoryID ?? 0);
                        });
                    }
                }
                delegate: WindowCard {
                    id: window
                    required property var modelData
                    required property int index
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id === monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    windowData: windowByAddress[address]
                    toplevel: modelData
                    monitorData: monitor
                    widgetMonitorData: root.monitorData
                    scale: root.scale
                    availableWorkspaceWidth: root.workspaceImplicitWidth
                    availableWorkspaceHeight: root.workspaceImplicitHeight
                    widgetMonitorId: root.monitor.id
                    recaptureToken: root.previewRecaptureToken

                    readonly property bool atInitPosition: (initX == x && initY == y)
                    readonly property int workspaceColIndex: root.getWorkspaceColumn(windowData?.workspace?.id)
                    readonly property int workspaceRowIndex: root.getWorkspaceRow(windowData?.workspace?.id)
                    readonly property int visibleWorkspaceRowIndex: root.getVisibleRowPosition(workspaceRowIndex)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * visibleWorkspaceRowIndex

                    z: atInitPosition ? (root.windowZ + index) : root.windowDraggingZ

                    Drag.hotSpot.x: targetWindowWidth / 2
                    Drag.hotSpot.y: targetWindowHeight / 2

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true
                        onExited: hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = windowData?.workspace?.id
                            root.draggingTargetSpecialWorkspace = ""
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                        }
                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace
                            const targetSpecialWorkspace = root.draggingTargetSpecialWorkspace
                            window.pressed = false
                            window.Drag.active = false
                            root.draggingFromWorkspace = -1
                            root.draggingTargetWorkspace = -1
                            root.draggingTargetSpecialWorkspace = ""
                            if (targetSpecialWorkspace === root.createSpecialWorkspaceTarget) {
                                const createdName = root.nextSpecialWorkspaceName()
                                OverviewService.moveToSpecial(windowData?.address, createdName)
                                updateWindowPosition.restart()
                            } else if (targetSpecialWorkspace && targetSpecialWorkspace !== root.specialWorkspaceName(windowData)) {
                                OverviewService.moveToSpecial(windowData?.address, targetSpecialWorkspace)
                                updateWindowPosition.restart()
                            } else if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace?.id) {
                                OverviewService.moveToWorkspace(windowData?.address, targetWorkspace)
                                updateWindowPosition.restart()
                            } else {
                                window.x = window.initX
                                window.y = window.initY
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;
                            if (event.button === Qt.LeftButton) {
                                OverviewService.close()
                                OverviewService.focusWindow(windowData.address)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                OverviewService.closeWindow(windowData.address)
                                event.accepted = true
                            }
                        }
                    }

                    // Tras mover una ventana, reposicionamos la tarjeta cuando
                    // los datos de hyprctl se actualizan (async).
                    Timer {
                        id: updateWindowPosition
                        interval: AppTheme.overviewRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(Math.max((windowData?.at[0] - (monitor?.x ?? 0) - (monitorData?.reserved?.[0] ?? 0)) * root.scale * window.widthRatio, 0) + xOffset)
                            window.y = Math.round(Math.max((windowData?.at[1] - (monitor?.y ?? 0) - (monitorData?.reserved?.[1] ?? 0)) * root.scale * window.heightRatio, 0) + yOffset)
                        }
                    }
                }
            }

            Rectangle { // Indicador del workspace activo
                id: focusedWorkspaceIndicator
                property int activeWorkspaceRowIndex: root.getWorkspaceRow(root.effectiveActiveWorkspaceId)
                property int visibleActiveWorkspaceRowIndex: root.getVisibleRowPosition(activeWorkspaceRowIndex)
                property int activeWorkspaceColIndex: root.getWorkspaceColumn(root.effectiveActiveWorkspaceId)
                x: (root.workspaceImplicitWidth + workspaceSpacing) * activeWorkspaceColIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * visibleActiveWorkspaceRowIndex
                z: root.windowDraggingZ - 1
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                radius: AppTheme.radiusLarge * root.scale
                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }

        // Capa por encima de todo para las ventanas special arrastradas.
        Item {
            id: specialWindowDragLayer
            anchors.fill: parent
            z: root.windowDraggingZ + 1
        }
    }
}
