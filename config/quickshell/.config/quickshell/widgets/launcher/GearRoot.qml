// widgets/launcher/GearRoot.qml
// Coordinador del launcher Gear: monta TRES engranajes (activo central, entrante
// derecho, decorativo izquierdo) y el hub central; orquesta la transición de
// cambio de página (rotación de roles entre izquierda/centro/derecha) y el
// "spin" de búsqueda contra la rotación de reposo del anillo.
//
// Modelo de transición (cambio de página, hacia delante):
//   1) El engranaje central se encoge y viaja a la izquierda (reemplaza al
//      satélite izquierdo, que queda como silueta sin corona).
//   2) El engranaje de la derecha (ya cargado con la corona de la NUEVA página)
//      crece y pasa al centro, convirtiéndose en el nuevo engranaje principal.
//   3) El satélite izquierdo sale del plano por la izquierda; y el engranaje
//      que salió se recoloca (invisible) por la derecha como nuevo decorativo.
// Hacia atrás es el espejo.
import QtQuick
import qs.globals
import qs.services
import qs.widgets.launcher

Item {
    id: root

    // ============================================================
    // GEOMETRÍA DE SLOTS (centros en el plano del GearRoot)
    // ============================================================
    readonly property real cx: AppTheme.launcherGearRadius + AppTheme.launcherSatGap + AppTheme.launcherSatRadius // 360
    readonly property real satOuter: AppTheme.launcherSatRadius + AppTheme.launcherSatToothH // 95
    readonly property real gearOuter: AppTheme.launcherGearRadius + AppTheme.launcherGearToothH // 284
    readonly property real centerX: root.cx + root.satOuter // centro del ensamblaje
    readonly property real slotY: Math.max(root.gearOuter, root.satOuter) // centro vertical
    readonly property real leftX: root.centerX - root.cx
    readonly property real rightX: root.centerX + root.cx
    readonly property real satScale: AppTheme.launcherSatRadius / AppTheme.launcherGearRadius // ~0.33
    readonly property real exitOff: -root.cx * 2 // fuera de plano por la izquierda
    readonly property real enterOff: root.centerX + root.cx * 2 // fuera de plano por la derecha
    readonly property int pageSize: LauncherState.gearSize
    readonly property int ms: AppTheme.launcherGearTransitionMs

    implicitWidth: (root.cx + root.satOuter) * 2
    implicitHeight: Math.max(root.gearOuter * 2, root.satOuter * 2)

    function currentPage() {
        if (AppModel.ringCount === 0)
            return 0;
        return Math.floor(AppModel.offset / root.pageSize);
    }

    // ============================================================
    // ROLES ACTUALES (qué gear ocupa cada slot)
    // ============================================================
    property var cGear: gA // central (activo, corona + hub)
    property var rGear: gB // entrante derecho
    property var lGear: gC // decorativo izquierdo
    property bool transitioning: false
    property int lastPage: 0
    property int lastDir: 1

    // ============================================================
    // DESPACHO DE CLICKS EN DIENTES
    // ============================================================
    function handleSlot(app) {
        if (!app)
            return;

        if (LauncherState.searching) {
            hub.setQuery(app.name);
        } else {
            AppModel.launch(app);
            LauncherState.close();
        }
    }

    function focusSearch() {
        hub.focusSearch();
    }

    // ============================================================
    // SETUP INICIAL DE POSICIONES
    // ============================================================
    function layoutSteady() {
        root.cGear.slotX = root.centerX;
        root.cGear.slotY = root.slotY;
        root.cGear.gearScale = 1.0;
        root.cGear.crownVisible = true;
        root.cGear.pageBase = -1;

        root.rGear.slotX = root.rightX;
        root.rGear.slotY = root.slotY;
        root.rGear.gearScale = root.satScale;
        root.rGear.crownVisible = false;
        root.rGear.opacity = 1;
        root.rGear.pageBase = -1;

        root.lGear.slotX = root.leftX;
        root.lGear.slotY = root.slotY;
        root.lGear.gearScale = root.satScale;
        root.lGear.crownVisible = false;
        root.lGear.opacity = 1;
        root.lGear.pageBase = -1;

        hub.hubX = root.centerX;
        hub.hubY = root.slotY;
        hub.hubScale = 1.0;

        root.lastPage = root.currentPage();
    }

    // Define la corona de un gear para una página destino (múltiplo de 8).
    function setGearPage(g, page) {
        g.pageBase = page * root.pageSize;
    }

    // ============================================================
    // TRANSICIÓN DE CAMBIO DE PÁGINA
    // `toPage`: página destino (page = floor(offset/8)). `forward` determina
    // la dirección de entrada (derecha siempre, salvo en el rebobinado).
    // ============================================================
    function doTransition(toPage, forward) {
        if (root.transitioning)
            return;
        root.transitioning = true;
        root.lastDir = forward ? 1 : -1;

        // Corona de la NUEVA página en el entrante (visible al llegar).
        const incoming = forward ? root.rGear : root.lGear;
        const outgoing = root.cGear;
        root.setGearPage(incoming, toPage);
        incoming.crownVisible = true;

        // El antiguo central deja de mostrar corona (se vuelve silueta).
        outgoing.crownVisible = false;

        if (forward) {
            // Central → izquierda, encogiendo (reemplaza al satélite izq).
            root.cGear.slotX = root.leftX;
            root.cGear.gearScale = root.satScale;
            // Entrante derecho → centro, creciendo.
            root.rGear.slotX = root.centerX;
            root.rGear.gearScale = 1.0;
            // Decorativo izquierdo sale por la izquierda.
            root.lGear.slotX = root.exitOff;
            root.lGear.gearScale = root.satScale;
            root.lGear.opacity = 0;
            // El hub viaja con el central saliente hacia la izquierda.
            hub.hubX = root.leftX;
            hub.hubScale = root.satScale;
        } else {
            // Central → derecha, encogiendo.
            root.cGear.slotX = root.rightX;
            root.cGear.gearScale = root.satScale;
            // Decorativo izquierdo → centro, creciendo (nuevo activo).
            root.lGear.slotX = root.centerX;
            root.lGear.gearScale = 1.0;
            // Decorativo derecho sale por la derecha.
            root.rGear.slotX = root.enterOff;
            root.rGear.gearScale = root.satScale;
            root.rGear.opacity = 0;
            // El hub viaja con el central saliente hacia la derecha.
            hub.hubX = root.rightX;
            hub.hubScale = root.satScale;
        }

        endTimer.start();
    }

    function finishTransition(forward) {
        const oldC = root.cGear;
        const oldR = root.rGear;
        const oldL = root.lGear;
        if (forward) {
            root.cGear = oldR; // entrante → central
            root.rGear = oldL; // salido por izq → decorativo derecho
            root.lGear = oldC; // antiguo central → decorativo izquierdo
        } else {
            root.cGear = oldL; // entrante izq → central
            root.lGear = oldR; // salido por der → decorativo izquierdo
            root.rGear = oldC; // antiguo central → decorativo derecho
        }

        root.cGear.pageBase = -1; // vuelve a seguir el offset global
        root.transitioning = false;

        // Reacomodar decorativos en sus slots (invisibles durante el traslado),
        // y devolver el hub al nuevo central.
        root.rGear.slotX = root.rightX;
        root.rGear.slotY = root.slotY;
        root.rGear.gearScale = root.satScale;
        root.rGear.crownVisible = false;

        root.lGear.slotX = root.leftX;
        root.lGear.slotY = root.slotY;
        root.lGear.gearScale = root.satScale;
        root.lGear.crownVisible = false;

        hub.hubX = root.centerX;
        hub.hubScale = 1.0;

        // Fade-in del decorativo que entró (el que quedó con opacity 0).
        if (!forward) {
            if (root.lGear.opacity === 0)
                root.lGear.opacity = 1;
        } else {
            if (root.rGear.opacity === 0)
                root.rGear.opacity = 1;
        }
    }

    Timer {
        id: endTimer
        interval: root.ms + 40
        repeat: false
        onTriggered: root.finishTransition(root.lastDir > 0)
    }

    // ============================================================
    // DETECCIÓN DE CAMBIO DE PÁGINA (cruces de páginas)
    // ============================================================
    Connections {
        target: AppModel

        function onOffsetChanged() {
            if (!AppModel.loaded || LauncherState.searching || !LauncherState.open)
                return;
            const p = root.currentPage();
            if (p !== root.lastPage && !root.transitioning) {
                root.doTransition(p, p > root.lastPage);
            }
            root.lastPage = p;
        }
    }

    // Al abrir el launcher el offset se resetea (resetOffset → 0); se
    // resincroniza lastPage para no lanzar una transición espuria.
    Connections {
        target: LauncherState

        function onOpenChanged() {
            if (LauncherState.open) {
                // resetOffset() pone offset=0 al abrir; sincronizar lastPage a 0
                // evita una transición espuria por el reorden/orden de handlers.
                root.lastPage = 0;
            }
        }
    }

    // Engranajes (activo central, entrante derecho, decorativo izquierdo).
    Gear {
        id: gA
        onClickedSlot: (app) => { return root.handleSlot(app); }
    }
    Gear {
        id: gB
        onClickedSlot: (app) => { return root.handleSlot(app); }
    }
    Gear {
        id: gC
        onClickedSlot: (app) => { return root.handleSlot(app); }
    }

    // Hub central (buscador + app enfocada), móvil con la transición.
    GearSearch {
        id: hub
        z: 20
    }

    // ============================================================
    // ORQUESTACIÓN DEL SPIN (solo el central activo)
    // ============================================================
    Connections {
        function onSearchingChanged() {
            if (LauncherState.searching)
                root.cGear.beginSpin();
            else
                root.cGear.endSpin();
        }

        target: LauncherState
    }

    Component.onCompleted: {
        layoutSteady();
    }
}
