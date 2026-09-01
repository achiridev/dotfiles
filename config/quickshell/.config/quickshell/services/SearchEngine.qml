// services/SearchEngine.qml
// Búsqueda del launcher Gear. Filtra y rankea sobre AppModel.apps (name,
// generic/keywords, exec, iniciales) y expone `targetOffset()` para que el
// anillo alinee el top result en el hub. Ranking ligero y síncrono (M < 400).
pragma Singleton
import QtQuick
import Quickshell

import qs.services

Singleton {
    id: root

    property string query: ""
    property var results: []          // apps rankeadas (top result primero)
    property bool searching: false    // query no vacía
    property bool empty: false        // searching && sin coincidencias

    function setQuery(text) {
        const t = (text || "").trim()
        root.query = t
        const qlow = t.toLowerCase()

        if (!t) {
            root.results = []
            root.searching = false
            root.empty = false
            return
        }

        const scored = []
        const apps = AppModel.apps
        for (let i = 0; i < apps.length; ++i) {
            const app = apps[i]
            const name = (app.name || "").toLowerCase()
            let score = 0
            if (name.startsWith(qlow)) score += 40
            else if (name.includes(qlow)) score += 20

            const kw = (app.keywords || "").toLowerCase()
            if (kw && kw.includes(qlow)) score += 6

            if ((app.exec || "").toLowerCase().includes(qlow)) score += 8

            if (score === 0 && root.initials(app.name).startsWith(qlow)) score += 12

            if (score > 0)
                scored.push({ app: app, score: score, name: name })
        }

        scored.sort((x, y) => {
            if (y.score !== x.score) return y.score - x.score
            return x.name.localeCompare(y.name)
        })

        root.results = scored.map(x => x.app)
        root.searching = true
        root.empty = root.results.length === 0
    }

    function clear() {
        root.setQuery("")
    }

    function initials(name) {
        const cjk = name.match(/[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]/g)
        if (cjk && cjk.length > 1) return cjk[0]
        return name
            .split(/[\s\-_./+()]+/)
            .map(w => w[0] || "")
            .join("")
            .toLowerCase()
    }

    // Índice (en AppModel.apps) al que debe alinearse el foco.
    function targetOffset() {
        if (root.results.length === 0) return -1
        return AppModel.apps.indexOf(root.results[0])
    }

    // Reorienta el anillo: el top result queda en el hub.
    function alignToTop() {
        const idx = root.targetOffset()
        if (idx < 0) return false
        AppModel.alignToIndex(idx)
        return true
    }

    function launchSelected() {
        AppModel.launchFocused()
    }
}