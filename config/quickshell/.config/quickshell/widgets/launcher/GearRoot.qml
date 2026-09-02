// widgets/launcher/GearRoot.qml
// Coordinador del launcher Gear: monta el engranaje principal, los satélites
// de overflow y el hub central; orquesta el "spin" de búsqueda contra la
// rotación de reposo del anillo y despacha los clicks de los dientes.
import QtQuick
import qs.globals
import qs.services
import qs.widgets.launcher

Item {
    id: root

    // ============================================================
    // DESPACHO DE CLICKS EN DIENTES
    // ============================================================
    function handleSlot(app) {
        if (!app)
            return ;

        if (LauncherState.searching) {
            // Navegar desde un diente hacia su resultado: precargar el nombre.
            hub.setQuery(app.name);
        } else {
            AppModel.launch(app);
            LauncherState.close();
        }
    }

    // El foco del buscador debe tomarse DESPUÉS de que el grab de teclado
    // exclusivo esté activo (lo invoca la ventana al abrir).
    function focusSearch() {
        hub.focusSearch();
    }

    implicitWidth: Math.max(gear.width, overflow.implicitWidth)
    implicitHeight: Math.max(gear.height, overflow.implicitHeight)

    // Engranaje principal (corona + cabina de hubs) centrado.
    Gear {
        id: gear

        anchors.centerIn: root
        onClickedSlot: (app) => {
            return root.handleSlot(app);
        }
    }

    // Satélites laterales (estáticos, muestran el overflow del anillo).
    GearOverflow {
        id: overflow

        anchors.centerIn: root
        gearRef: gear
        enabled: AppModel.ringCount > LauncherState.gearSize
        opacity: AppModel.ringCount > LauncherState.gearSize ? 1 : 0
        visible: AppModel.ringCount > LauncherState.gearSize
    }

    // Hub central (buscador + app enfocada) flotando sobre el engranaje.
    GearSearch {
        id: hub

        anchors.centerIn: root
        z: 20
    }

    // ============================================================
    // ORQUESTACIÓN DEL SPIN
    // ============================================================
    Connections {
        function onSearchingChanged() {
            if (LauncherState.searching)
                gear.beginSpin();
            else
                gear.endSpin();
        }

        target: LauncherState
    }

}
