// widgets/launcher/GearSearch.qml
// Hub central del launcher: círculo de vidrio con la app enfocada y el
// buscador. Todo el input de teclado del launcher vive aquí (flechas, Enter,
// Esc). El hub no rota; flota sobre el engranaje.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.globals
import qs.services

Rectangle {
    id: root

    readonly property real hubSize: AppTheme.launcherCenterSize
    readonly property var focusApp: AppModel.focusApp()
    property bool hubSearching: false
    property int resultIndex: 0
    // Nombre de la app central: autofit (reduce fuente para que quepa en el
    // ancho del hub, permitiendo varias líneas).
    readonly property real baseNameSize: 14
    readonly property int maxNameLines: 2
    readonly property real nameAvailW: column.width - 8
    // ============================================================
    // ESTADOS VISUALES DERIVADOS
    // ============================================================
    readonly property string countHint: AppModel.loading ? "Cargando apps…" : (AppModel.count === 0 ? "No hay aplicaciones" : "Buscar aplicación…")
    readonly property bool showingSearch: root.hubSearching && SearchEngine.results.length > 0
    readonly property var displayApp: root.showingSearch ? SearchEngine.results[root.resultIndex] : root.focusApp
    readonly property string currentDisplayName: AppModel.count === 0 ? (AppModel.loading ? "Cargando…" : "Sin aplicaciones") : (displayApp ? displayApp.name : "")
    readonly property string statusHint: root.hubSearching ? (root.showingSearch ? (SearchEngine.results.length > 1 ? (root.resultIndex + 1) + " de " + SearchEngine.results.length + " resultados" : "1 resultado") : "sin resultados") : ""
    readonly property color statusHintColor: root.hubSearching && !root.showingSearch ? AppTheme.critical : AppTheme.textTertiary
    // Icono resuelto de la app enfocada / resultado (fallback genérico).
    readonly property string displayIcon: {
        const name = root.displayApp && root.displayApp.icon ? String(root.displayApp.icon).trim() : "";
        if (name !== "" && Quickshell.hasThemeIcon(name))
            return Quickshell.iconPath(name);
        return Quickshell.iconPath("application-x-executable");
    }
    // Líneas estimadas para el nombre (aprox. por ancho total) y tamaño de
    // fuente resultante: si no cabe en maxNameLines, se reduce.
    readonly property int nameLines: root.currentDisplayName === "" ? 1 : Math.max(1, Math.ceil(nameMetrics.advanceWidth(root.currentDisplayName) / Math.max(1, root.nameAvailW)))
    readonly property real focusTextSize: {
        const l = root.nameLines;
        if (l <= root.maxNameLines)
            return root.baseNameSize;
        return Math.max(9, root.baseNameSize * root.maxNameLines / l);
    }

    // ============================================================
    // NAVEGACIÓN POR TECLADO (browse vs búsqueda)
    // ============================================================
    // Left/Right solo orbitan el anillo en modo browse. En búsqueda NO se
    // aceptan: dejan que el TextInput maneje el cursor (editar la query).
    function arrowLeft() {
        LauncherState.rotate(-1);
    }

    function arrowRight() {
        LauncherState.rotate(1);
    }

    function arrowUp() {
        if (root.hubSearching)
            root.moveResult(-1);
        else
            LauncherState.page(-1);
    }

    function arrowDown() {
        if (root.hubSearching)
            root.moveResult(1);
        else
            LauncherState.page(1);
    }

    function moveResult(dir) {
        const n = SearchEngine.results.length;
        if (n === 0)
            return ;

        root.resultIndex = ((root.resultIndex + dir) % n + n) % n;
        const idx = AppModel.apps.indexOf(SearchEngine.results[root.resultIndex]);
        if (idx >= 0)
            AppModel.alignToIndex(idx);

    }

    function confirm() {
        // Con búsqueda activa pero sin coincidencias, Enter no debe lanzar la
        // app que quedó alineada (invisible): no hacer nada.
        if (root.hubSearching && SearchEngine.results.length === 0)
            return;

        const app = root.hubSearching && SearchEngine.results.length > 0 ? SearchEngine.results[root.resultIndex] : AppModel.focusApp();
        AppModel.launch(app);
        LauncherState.close();
    }

    function setQuery(q) {
        searchInput.text = q;
    }

    // ============================================================
    // BÚSQUEDA (sincroniza SearchEngine <-> estado del launcher)
    // ============================================================
    function applyQuery(q) {
        SearchEngine.setQuery(q);
        if (SearchEngine.searching) {
            SearchEngine.alignToTop();
            root.resultIndex = 0;
        } else {
            root.resultIndex = 0;
        }
    }

    function focusSearch() {
        searchInput.forceActiveFocus();
    }

    width: root.hubSize
    height: root.hubSize
    radius: root.hubSize / 2
    color: Qt.alpha(AppTheme.bgPopup, 0.85)
    border.width: 2
    border.color: root.hubSearching ? Qt.alpha(AppTheme.accent, 0.9) : Qt.alpha(AppTheme.color4, 0.7)
    onHubSearchingChanged: {
        if (root.hubSearching)
            LauncherState.beginSearch();
        else
            LauncherState.endSearch();
    }

    // Aro interior decorativo: anillo concéntrico de acento.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 5
        radius: (root.hubSize - 10) / 2
        color: "transparent"
        border.width: 1.5
        border.color: Qt.alpha(AppTheme.color4, 0.45)

        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }

        }

    }

    // Métricas para el autofit del nombre de la app central.
    FontMetrics {
        id: nameMetrics

        font.family: AppTheme.fontMono
        font.weight: Font.Bold
        font.pixelSize: root.baseNameSize
    }

    // ============================================================
    // UI
    // ============================================================
    Column {
        id: column

        anchors.centerIn: parent
        width: parent.width - AppTheme.paddingLarge * 2
        spacing: AppTheme.paddingBase

        // --- Fila buscador ---
        Row {
            width: parent.width
            spacing: AppTheme.paddingBase

            IconImage {
                width: 13
                height: 13
                anchors.verticalCenter: parent.verticalCenter
                source: Quickshell.iconPath("system-search", true)
                opacity: 0.8
            }

            // Wrapper para el placeholder (TextInput plano no tiene
            // placeholderText): un Text encima visible solo sin texto.
            Item {
                width: parent.width - 28
                height: searchInput.implicitHeight + 4
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    color: AppTheme.textTertiary
                    font.family: AppTheme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    text: root.countHint
                }

                TextInput {
                    id: searchInput

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: AppTheme.fg
                    selectionColor: Qt.alpha(AppTheme.accent, 0.4)
                    selectedTextColor: AppTheme.fg
                    font.family: AppTheme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    clip: true
                    cursorVisible: true
                    Keys.forwardTo: controller
                    onTextChanged: root.applyQuery(searchInput.text)
                }

            }

        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(AppTheme.borderColor, 0.35)
        }

        // --- Insignia de la selección (icono + nombre del foco/resultado) ---
        Column {
            width: parent.width
            spacing: 6

            IconImage {
                width: 30
                height: 30
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.displayApp !== null
                source: root.displayIcon
            }

            Text {
                id: focusName

                width: parent.width
                visible: !root.showingSearch && root.currentDisplayName !== ""
                text: root.currentDisplayName
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                font.family: AppTheme.fontMono
                font.pixelSize: root.focusTextSize
                font.weight: Font.Bold
                color: AppTheme.fg
            }

            Text {
                width: parent.width
                visible: root.showingSearch
                text: root.statusHint
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.family: AppTheme.fontMono
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: root.statusHintColor
            }

        }

    }

    // ============================================================
    // CONTROLLER (teclas para el TextInput)
    // ============================================================
    Item {
        id: controller

        focus: true
        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Left:
                // En búsqueda NO se acepta: el cursor del TextInput lo maneja el
                // propio TextInput (editar en medio de la query).
                if (!root.hubSearching) {
                    root.arrowLeft();
                    event.accepted = true;
                }
                break;
            case Qt.Key_Right:
                if (!root.hubSearching) {
                    root.arrowRight();
                    event.accepted = true;
                }
                break;
            case Qt.Key_Up:
                root.arrowUp();
                event.accepted = true;
                break;
            case Qt.Key_Down:
                root.arrowDown();
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.confirm();
                event.accepted = true;
                break;
            case Qt.Key_Escape:
                if (searchInput.text.length > 0) {
                    searchInput.text = "";
                    SearchEngine.clear();
                    root.resultIndex = 0;
                } else {
                    LauncherState.close();
                }
                event.accepted = true;
                break;
            default:
                break;
            }
        }
    }

    // ============================================================
    // CONEXIONES EXTERNAS
    // ============================================================
    // El hub es un área interactiva: absorber los clics para que no lleguen al
    // catcher de "click fuera = cerrar".
    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => {
            mouse.accepted = true;
        }
    }

    Connections {
        function onOpenChanged() {
            if (LauncherState.open) {
                searchInput.forceActiveFocus();
                searchInput.text = "";
                SearchEngine.clear();
                root.resultIndex = 0;
                AppModel.resetOffset();
                AppModel.refresh();
            } else {
                root.hubSearching = false;
            }
        }

        target: LauncherState
    }

    Connections {
        function onSearchingChanged() {
            root.hubSearching = SearchEngine.searching;
        }

        target: SearchEngine
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 200
        }

    }

}
