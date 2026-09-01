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
    // ============================================================
    // ESTADOS VISUALES DERIVADOS
    // ============================================================
    readonly property string countHint: AppModel.loading ? "Cargando apps…" : (AppModel.count === 0 ? "No hay aplicaciones" : "Buscar aplicación…")
    readonly property bool showingSearch: root.hubSearching && SearchEngine.results.length > 0
    readonly property var displayApp: root.showingSearch ? SearchEngine.results[root.resultIndex] : root.focusApp
    readonly property string currentDisplayName: AppModel.count === 0 ? (AppModel.loading ? "Cargando…" : "Sin aplicaciones") : (displayApp ? displayApp.name : "")
    readonly property string statusHint: root.hubSearching ? (root.showingSearch ? (SearchEngine.results.length > 1 ? (root.resultIndex + 1) + " de " + SearchEngine.results.length + " resultados" : "1 resultado") : "sin resultados") : ""
    readonly property color statusHintColor: root.hubSearching && !root.showingSearch ? AppTheme.critical : AppTheme.textTertiary
    readonly property string hintBar: root.hubSearching ? "↵ Lanzar · ↑↓ Resultado · Esc Cerrar" : "↵ Lanzar · ←→ Orbitar · ↑↓ Página · Esc Cerrar"

    // ============================================================
    // NAVEGACIÓN POR TECLADO (browse vs búsqueda)
    // ============================================================
    function arrowLeft() {
        if (!root.hubSearching)
            LauncherState.rotate(-1);

    }

    function arrowRight() {
        if (!root.hubSearching)
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
                width: 15
                height: 15
                anchors.verticalCenter: parent.verticalCenter
                source: Quickshell.iconPath("system-search", true)
                opacity: 0.8
            }

            // Wrapper para el placeholder (TextInput plano no tiene
            // placeholderText): un Text encima visible solo sin texto.
            Item {
                width: parent.width - 26
                height: searchInput.implicitHeight + 4
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    color: AppTheme.textTertiary
                    font.family: AppTheme.fontMono
                    font.pixelSize: 10
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
                    font.pixelSize: 10
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

        // --- Insignia de la selección (el foco está en el diente superior) ---
        Item {
            width: parent.width
            height: 44

            Text {
                id: focusName

                anchors.centerIn: parent
                width: parent.width
                visible: !root.showingSearch && root.currentDisplayName !== ""
                text: root.currentDisplayName
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                font.family: AppTheme.fontMono
                font.pixelSize: 12
                font.weight: Font.Bold
                color: AppTheme.fg
            }

            Text {
                anchors.centerIn: parent
                width: parent.width
                visible: root.showingSearch
                text: root.statusHint
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.family: AppTheme.fontMono
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: root.statusHintColor
            }

        }

        // --- Barra de teclas ---
        Text {
            width: parent.width
            text: root.hintBar
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: AppTheme.fontMono
            font.pixelSize: 8
            color: AppTheme.textTertiary
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
                root.arrowLeft();
                event.accepted = true;
                break;
            case Qt.Key_Right:
                root.arrowRight();
                event.accepted = true;
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
