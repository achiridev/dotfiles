// utils/ClipboardUtils.js
//
// Lógica PURA del portapapeles: parseo de `cliphist list`, clasificación de
// contenido, saneado de previews, búsqueda y formateo de metadatos.
//
// No importa QtQuick, Quickshell ni ningún servicio: se puede ejecutar en
// Node/Qt y testear sin arrancar la shell. La capa visual NUNCA debería
// implementar estas reglas.
//
// Contrato de una entrada (lo que consume la UI):
//   {
//     id:       "57767",        // string, tal cual lo da cliphist
//     preview:  "texto…",       // preview saneado de una línea
//     summary:  "texto…",       // igual que preview (la UI decide el elide)
//     kind:     "text" | "image" | "binary",
//     format:   "PNG",          // etiqueta legible ("" si no aplica)
//     bytes:    12345,          // tamaño en bytes (0 si desconocido)
//     width:    640,            // solo imágenes (0 si no aplica)
//     height:   480,
//     sizeLabel:"12.1 KiB",     // cadena vacía si se desconoce
//     kindLabel:"Imagen",       // etiqueta legible del tipo
//     meta:     "PNG · 640×480 · 12.1 KiB",
//     search:   "texto normalizado para buscar"
//   }
//
// El ID es string a propósito: los IDs de cliphist son números grandes y en
// JS perderían precisión si se convirtieran a Number.

.pragma library

var IMAGE_RE = /^\[\[\s*binary data\s+(\d+(?:\.\d+)?)\s+(B|KiB|MiB|GiB)\s+([A-Za-z0-9.+-]+)\s+(\d+)x(\d+)\s*\]\]$/i
var SIZE_MULTIPLIERS = {
    b: 1,
    kib: 1024,
    mib: 1024 * 1024,
    gib: 1024 * 1024 * 1024
}
var CONTROL_RE = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g
var REPLACEMENT_RE = /\uFFFD/g

var FORMAT_LABELS = {
    jpeg: "JPEG",
    jpg: "JPEG",
    png: "PNG",
    gif: "GIF",
    webp: "WebP",
    bmp: "BMP",
    svg: "SVG",
    tiff: "TIFF",
    tif: "TIFF",
    avif: "AVIF",
    heic: "HEIC",
    heif: "HEIF"
}

var KIND_LABELS = {
    text: "Texto",
    image: "Imagen",
    binary: "Binario"
}

// Elimina NUL y caracteres de control, colapsa espacios y recorta. cliphist ya
// convierte los saltos de línea en espacios en el preview, pero un binario
// puede colar bytes de control.
function sanitize(text) {
    if (text === undefined || text === null)
        return ""
    return String(text)
        .replace(/\u0000/g, "")
        .replace(CONTROL_RE, " ")
        .replace(/\s+/g, " ")
        .trim()
}

function humanBytes(bytes) {
    var n = Number(bytes)
    if (!isFinite(n) || n <= 0)
        return ""
    if (n < 1024)
        return n + " B"
    var units = ["KiB", "MiB", "GiB"]
    var value = n
    var unit = "B"
    for (var i = 0; i < units.length; ++i) {
        value /= 1024
        unit = units[i]
        if (value < 1024)
            break
    }
    var decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2)
    return value.toFixed(decimals).replace(/\.0+$/, "") + " " + unit
}

function formatLabel(format) {
    var key = String(format || "").toLowerCase()
    return FORMAT_LABELS[key] || String(format || "").toUpperCase()
}

// Detecta contenedores conocidos que cliphist muestra como si fueran texto
// (PDF, ZIP, RAR, 7z, MP4/Ogg/RIFF…). Devuelve "" si no reconoce nada.
function detectMagic(raw) {
    if (!raw)
        return ""
    if (raw.indexOf("%PDF-") === 0)
        return "PDF"
    if (raw.indexOf("PK\u0003\u0004") === 0 || raw.indexOf("PK\u0005\u0006") === 0)
        return "ZIP"
    if (raw.indexOf("Rar!") === 0)
        return "RAR"
    if (raw.indexOf("7z\u00bc\u00af\u0027\u001c") === 0)
        return "7Z"
    if (raw.indexOf("OggS") === 0)
        return "OGG"
    if (raw.indexOf("RIFF") === 0)
        return "RIFF"
    if (raw.indexOf("ID3") === 0)
        return "MP3"
    if (raw.indexOf("GIF87a") === 0 || raw.indexOf("GIF89a") === 0)
        return "GIF"
    if (raw.indexOf("\u0089PNG") === 0)
        return "PNG"
    return ""
}

function looksBinary(raw) {
    if (!raw)
        return false
    var controls = (raw.match(CONTROL_RE) || []).length
    if (controls > 0)
        return true
    var replacements = (raw.match(REPLACEMENT_RE) || []).length
    // cliphist sustituye bytes no-UTF8 por U+FFFD. Un texto real casi nunca
    // tiene una proporción alta de reemplazos.
    return raw.length >= 8 && replacements / raw.length > 0.02
}

// Convierte una línea cruda `id<TAB>preview` en una entrada de la UI.
// Devuelve null para líneas vacías o mal formadas.
function parseLine(line) {
    if (line === undefined || line === null)
        return null

    var raw = String(line)
    if (raw.length === 0)
        return null
    if (raw.charAt(raw.length - 1) === "\r")
        raw = raw.slice(0, -1)

    var tab = raw.indexOf("\t")
    if (tab <= 0)
        return null

    var id = raw.slice(0, tab).trim()
    if (!id)
        return null

    var rawPreview = raw.slice(tab + 1)
    var preview = sanitize(rawPreview)

    var entry = {
        id: id,
        preview: preview,
        summary: preview,
        kind: "text",
        format: "",
        bytes: 0,
        width: 0,
        height: 0,
        sizeLabel: "",
        kindLabel: KIND_LABELS.text,
        meta: KIND_LABELS.text,
        search: ""
    }

    var match = IMAGE_RE.exec(rawPreview)
    if (match) {
        entry.kind = "image"
        var amount = parseFloat(match[1])
        if (!isFinite(amount))
            amount = 0
        var unit = String(match[2]).toLowerCase()
        entry.bytes = Math.round(amount * (SIZE_MULTIPLIERS[unit] || 1))
        entry.format = formatLabel(match[3])
        entry.width = parseInt(match[4], 10) || 0
        entry.height = parseInt(match[5], 10) || 0
        entry.sizeLabel = humanBytes(entry.bytes)
        entry.kindLabel = KIND_LABELS.image

        var parts = [entry.format]
        if (entry.width > 0 && entry.height > 0)
            parts.push(entry.width + "×" + entry.height)
        if (entry.sizeLabel)
            parts.push(entry.sizeLabel)
        entry.meta = parts.join(" · ")
    } else {
        var magic = detectMagic(rawPreview)
        if (magic || looksBinary(rawPreview)) {
            entry.kind = "binary"
            entry.format = magic || "BIN"
            entry.kindLabel = KIND_LABELS.binary
            entry.meta = entry.format === "BIN" ? KIND_LABELS.binary : entry.format
        } else {
            if (!entry.preview)
                entry.preview = ""
            entry.summary = entry.preview
            entry.meta = KIND_LABELS.text
        }
    }

    // El preview de imagen es `[[ binary data … ]]`: no aporta nada a la
    // búsqueda y ensuciaría el resumen. Para imágenes/binarios se busca por
    // su etiqueta legible y metadatos ("imagen png 640x480"); para texto se
    // busca por el propio contenido.
    if (entry.kind === "text") {
        entry.search = normalize(entry.preview)
    } else {
        var searchable = entry.kindLabel + " " + entry.meta + " " + entry.preview
        if (entry.kind === "image" && entry.width > 0 && entry.height > 0)
            searchable += " " + entry.width + "x" + entry.height
        entry.search = normalize(searchable)
    }
    return entry
}

function parseList(raw) {
    var out = []
    if (!raw)
        return out

    var lines = String(raw).split("\n")
    for (var i = 0; i < lines.length; ++i) {
        var entry = parseLine(lines[i])
        if (entry)
            out.push(entry)
    }
    return out
}

// Minúsculas + sin acentos (mapa manual: no dependemos de String.normalize,
// que no está garantizado en todos los motores QML).
function normalize(text) {
    if (text === undefined || text === null)
        return ""
    return String(text)
        .toLowerCase()
        .replace(/[áàäâã]/g, "a")
        .replace(/[éèëê]/g, "e")
        .replace(/[íìïî]/g, "i")
        .replace(/[óòöôõ]/g, "o")
        .replace(/[úùüû]/g, "u")
        .replace(/ñ/g, "n")
        .replace(/ç/g, "c")
        .replace(/\s+/g, " ")
        .trim()
}

// Filtra por tokens: todas las palabras deben aparecer (en cualquier orden).
// Mantiene el orden de recencia de cliphist; no reordena por score.
function filterEntries(entries, query) {
    if (!entries || entries.length === 0)
        return []
    var q = normalize(query)
    if (!q)
        return entries

    var tokens = q.split(" ").filter(function(t) { return t.length > 0 })
    if (tokens.length === 0)
        return entries

    var out = []
    for (var i = 0; i < entries.length; ++i) {
        var haystack = entries[i].search || ""
        var ok = true
        for (var j = 0; j < tokens.length; ++j) {
            if (haystack.indexOf(tokens[j]) === -1) {
                ok = false
                break
            }
        }
        if (ok)
            out.push(entries[i])
    }
    return out
}

function countImages(entries) {
    var n = 0
    for (var i = 0; entries && i < entries.length; ++i) {
        if (entries[i].kind === "image")
            ++n
    }
    return n
}

function findById(entries, id) {
    for (var i = 0; entries && i < entries.length; ++i) {
        if (entries[i].id === String(id))
            return entries[i]
    }
    return null
}
