// widgets/launcher/GearRoot.qml
// Coordinador del launcher Gear: monta CUATRO engranajes (activo central,
// entrante derecho, decorativo izquierdo y un "entrante" de reserva) y el hub
// central; orquesta la transición de cambio de página (rotación de roles entre
// los slots) y el "spin" de búsqueda contra la rotación de reposo del anillo.
//
// Modelo de transición (cambio de página, hacia delante), TODO en la misma
// ventana de 600ms y de forma simultánea:
//   1) El engranaje central se encoge y viaja a la izquierda (nuevo satélite).
//   2) El engranaje de la derecha (ya cargado con la corona de la NUEVA página)
//      crece y pasa al centro, convirtiéndose en el nuevo engranaje principal.
//   3) El satélite izquierdo sale del plano por la izquierda.
//   4) El engranaje de reserva entra por la derecha como nuevo satélite y el
//      hub acompaña al central saliente y vuelve al centro — todo a la vez.
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
    property var eGear: gD // reserva parqueada (próximo satélite que entrará)
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
        const pg = root.currentPage();

        root.cGear.slotX = root.centerX;
        root.cGear.slotY = root.slotY;
        root.cGear.gearScale = 1.0;
        root.cGear.crownVisible = true;
        root.cGear.pageBase = -1;
        root.cGear.poseTo(root.cGear.restPose(), false);

        root.setGearPage(root.rGear, pg + 1);
        root.rGear.slotX = root.rightX;
        root.rGear.slotY = root.slotY;
        root.rGear.gearScale = root.satScale;
        root.rGear.crownVisible = true;
        root.rGear.opacity = 1;
        root.rGear.poseTo(root.rGear.restPose(), false);

        root.setGearPage(root.lGear, pg - 1);
        root.lGear.slotX = root.leftX;
        root.lGear.slotY = root.slotY;
        root.lGear.gearScale = root.satScale;
        root.lGear.crownVisible = true;
        root.lGear.opacity = 1;
        root.lGear.poseTo(root.lGear.restPose(), false);

        // El engranaje de reserva se aparca fuera de plano, invisible, listo
        // para ser el próximo satélite entrante.
        root.eGear.opacity = 0;
        root.eGear.gearScale = root.satScale;
        root.eGear.snap(root.enterOff, root.slotY, root.satScale);

        hub.hubX = root.centerX;
        hub.hubY = root.slotY;
        hub.hubScale = 1.0;

        root.lastPage = pg;
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
        incoming.poseTo(incoming.restPose(), true);

        // El antiguo central pasa a ser satélite: muestra la página contigua
        // según la dirección (el de la izquierda muestra la anterior, el de la
        // derecha la siguiente) y re-posiciona su dial.
        root.setGearPage(outgoing, forward ? toPage - 1 : toPage + 1);
        outgoing.crownVisible = true;
        outgoing.poseTo(outgoing.restPose(), true);

        // Todo esto arranca a la vez (misma ventana de 600ms):
        const entering = root.eGear;
        if (forward) {
            // Central → izquierda, encogiendo (satélite de la página anterior).
            root.cGear.slotX = root.leftX;
            root.cGear.gearScale = root.satScale;
            // Entrante derecho → centro, creciendo.
            root.rGear.slotX = root.centerX;
            root.rGear.gearScale = 1.0;
            // Decorativo izquierdo sale por la izquierda.
            root.lGear.slotX = root.exitOff;
            root.lGear.gearScale = root.satScale;
            root.lGear.opacity = 0;
            // Nuevo satélite derecho entra desde el borde derecho,
            // CONCURRENTE con todo lo anterior.
            root.setGearPage(entering, toPage + 1);
            entering.crownVisible = true;
            entering.poseTo(entering.restPose(), false);
            entering.snap(root.enterOff, root.slotY, root.satScale);
            entering.slotX = root.rightX; // desliza derecha→izquierda
            entering.opacity = 1;
            // El hub acompaña al central saliente hacia la izquierda.
            hub.hubX = root.leftX;
            hub.hubScale = root.satScale;
        } else {
            // Central → derecha, encogiendo (satélite de la página siguiente).
            root.cGear.slotX = root.rightX;
            root.cGear.gearScale = root.satScale;
            // Decorativo izquierdo → centro, creciendo (nuevo activo).
            root.lGear.slotX = root.centerX;
            root.lGear.gearScale = 1.0;
            // Decorativo derecho sale por la derecha.
            root.rGear.slotX = root.enterOff;
            root.rGear.gearScale = root.satScale;
            root.rGear.opacity = 0;
            // Nuevo satélite izquierdo entra desde el borde izquierdo,
            // CONCURRENTE con todo lo anterior.
            root.setGearPage(entering, toPage - 1);
            entering.crownVisible = true;
            entering.poseTo(entering.restPose(), false);
            entering.snap(root.exitOff, root.slotY, root.satScale);
            entering.slotX = root.leftX; // desliza izquierda→derecha
            entering.opacity = 1;
            // El hub acompaña al central saliente hacia la derecha.
            hub.hubX = root.rightX;
            hub.hubScale = root.satScale;
        }

        // endTimer primero: libera `transitioning` aunque algo falle después.
        endTimer.start();
        returnTimer.restart();
    }

    function finishTransition(forward) {
        root.transitioning = false;

        const oldC = root.cGear;
        const oldR = root.rGear;
        const oldL = root.lGear;
        const oldE = root.eGear;
        if (forward) {
            // Entrante (ya en el centro) → central; antiguo central → izquierda;
            // el que entró por la derecha → derecha; el que salió → reserva.
            root.cGear = oldR;
            root.lGear = oldC;
            root.rGear = oldE;
            root.eGear = oldL;
        } else {
            // Entrante izquierdo → central; antiguo central → derecha;
            // el que entró por la izquierda → izquierda; el que salió → reserva.
            root.cGear = oldL;
            root.rGear = oldC;
            root.lGear = oldE;
            root.eGear = oldR;
        }

        root.cGear.pageBase = -1; // vuelve a seguir el offset global
        root.cGear.poseTo(root.cGear.restPose(), true);

        // Aparcar la reserva fuera de plano para la próxima transición.
        root.eGear.opacity = 0;
        root.eGear.snap(root.enterOff, root.slotY, root.satScale);
    }

    Timer {
        id: endTimer
        interval: root.ms + 40
        repeat: false
        onTriggered: root.finishTransition(root.lastDir > 0)
    }

    // Devuelve el hub al centro a mitad de la ventana de transición: así el hub
    // acompaña al central saliente durante la primera mitad y vuelve al centro
    // con el nuevo central durante la segunda, todo dentro de los 600ms.
    Timer {
        id: returnTimer
        interval: root.ms / 2
        repeat: false
        onTriggered: {
            hub.hubX = root.centerX;
            hub.hubScale = 1.0;
        }
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

    // Engranajes (activo central, entrante derecho, decorativo izquierdo, reserva).
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
    Gear {
        id: gD
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
