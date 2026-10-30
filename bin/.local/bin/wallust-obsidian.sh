#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  wallust-obsidian.sh — sincroniza la paleta de Wallust con el Vault Obsidian
# ══════════════════════════════════════════════════════════════════════════════
#  Se ejecuta después de renderizar las plantillas de Wallust (panel de control
#  o cambio de wallpaper). Hace cuatro cosas:
#
#    1. Recolorea la paleta de `obsidian-file-color` (conserva IDs y asignaciones).
#    2. Recolorea la paleta custom de `colored-tags`.
#    3. Recolorea los grupos del grafo (`graph.json`).
#    4. Añade el bloque HSL del acento (color5) al snippet `wallust.css`,
#       necesario porque Obsidian usa --accent-h/s/l en sus componentes.
#
#  Es idempotente: se puede ejecutar tantas veces como haga falta.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
OBSIDIAN_DIR="${OBSIDIAN_DIR:-$REPO_DIR/config/obsidian/achiri/.obsidian}"
COLORS_JSON="${WALLUST_COLORS:-$HOME/.cache/wallust/colors.json}"
SNIPPET="$OBSIDIAN_DIR/snippets/wallust.css"

if [ ! -f "$COLORS_JSON" ]; then
    echo "wallust-obsidian: no existe $COLORS_JSON" >&2
    exit 0
fi

if [ ! -d "$OBSIDIAN_DIR" ]; then
    echo "wallust-obsidian: no existe el Vault en $OBSIDIAN_DIR" >&2
    exit 0
fi

python3 - "$COLORS_JSON" "$OBSIDIAN_DIR" "$SNIPPET" <<'PY'
import json
import sys
from pathlib import Path

colors_path, obsidian_dir, snippet_path = map(Path, sys.argv[1:4])
data = json.loads(colors_path.read_text())
colors = data["colors"]


def get(name, fallback):
    value = colors.get(name, fallback)
    return value if isinstance(value, str) and value.startswith("#") else fallback


def rgb_int(hex_color):
    h = hex_color.lstrip("#")
    return int(h[0:2], 16) << 16 | int(h[2:4], 16) << 8 | int(h[4:6], 16)


# Orden semántico de la paleta para los elementos del Vault (aprox. al orden
# original de la paleta de obsidian-file-color: rosa, morado, verde, azul...).
palette = [
    get("color13", "#f5c2e7"), # rosa
    get("color5", "#cba6f7"),  # morado / accent
    get("color2", "#a6e3a1"),  # verde / success
    get("color4", "#89b4fa"),  # azul / info
    get("color3", "#f9e2af"),  # amarillo / warning
    get("color6", "#89dceb"),  # cyan
    get("color12", "#89b4fa"), # azul claro
    get("color11", "#fab387"), # naranja
    get("color1", "#f38ba8"),  # rojo / danger
]

# Color semántico por grupo del grafo (según la carpeta).
graph_map = {
    "backend": "color4",
    "semestre03": "color13",
    "arch linux": "color6",
    "diarias": "color5",
    "multivault": "color3",
    "semestre04": "color2",
}


def load_json(path):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def save_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(path)


# ── 1. obsidian-file-color ────────────────────────────────────────────────
file_color_path = obsidian_dir / "plugins/obsidian-file-color/data.json"
file_color = load_json(file_color_path)
if isinstance(file_color, dict) and isinstance(file_color.get("palette"), list):
    for index, entry in enumerate(file_color["palette"]):
        if isinstance(entry, dict):
            entry["value"] = palette[index % len(palette)]
    save_json(file_color_path, file_color)

# ── 2. colored-tags ───────────────────────────────────────────────────────
tags_path = obsidian_dir / "plugins/colored-tags/data.json"
tags = load_json(tags_path)
if isinstance(tags, dict):
    tag_palette = [get("color1", palette[0]), get("color3", palette[4]),
                   get("color2", palette[2]), get("color4", palette[3]),
                   get("color5", palette[1])]
    tags["palette"] = tags.get("palette", {})
    tags["palette"]["custom"] = "-".join(c.lstrip("#").lower() for c in tag_palette)
    save_json(tags_path, tags)

# ── 3. graph.json ─────────────────────────────────────────────────────────
graph_path = obsidian_dir / "graph.json"
graph = load_json(graph_path)
if isinstance(graph, dict) and isinstance(graph.get("colorGroups"), list):
    for index, group in enumerate(graph["colorGroups"]):
        if not isinstance(group, dict):
            continue
        query = str(group.get("query", "")).lower()
        hex_color = None
        for key, color_name in graph_map.items():
            if key in query:
                hex_color = get(color_name, palette[index % len(palette)])
                break
        if hex_color is None:
            hex_color = palette[index % len(palette)]
        group["color"] = {"a": 1, "rgb": rgb_int(hex_color)}
    save_json(graph_path, graph)

# ── 4. Bloque HSL del acento en el snippet ────────────────────────────────
accent = get("color5", "#cba6f7").lstrip("#")
r, g, b = (int(accent[i:i + 2], 16) / 255 for i in (0, 2, 4))
mx, mn = max(r, g, b), min(r, g, b)
light = (mx + mn) / 2
delta = mx - mn
if delta == 0:
    hue = sat = 0.0
else:
    sat = delta / (1 - abs(2 * light - 1))
    if mx == r:
        hue = ((g - b) / delta) % 6
    elif mx == g:
        hue = (b - r) / delta + 2
    else:
        hue = (r - g) / delta + 4
    hue *= 60


def linear(channel):
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def luminance_of(hex_color):
    h = hex_color.lstrip("#")
    rgb = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    r_, g_, b_ = rgb
    return 0.2126 * linear(r_) + 0.7152 * linear(g_) + 0.0722 * linear(b_)


def on_color(hex_color):
    # Punto de corte donde el contraste con negro y con blanco se iguala
    # (luminancia relativa ≈ 0.179). Debajo: texto claro; encima: texto oscuro.
    return "#101010" if luminance_of(hex_color) > 0.18 else "#F5F5F5"


on_accent = on_color(get("color5", "#cba6f7"))
on_danger = on_color(get("color1", "#f38ba8"))

block = (
    "\n/* achiri:accent-hsl:begin — generado por wallust-obsidian.sh */\n"
    ":root {\n"
    f"  --accent-h: {hue:.0f};\n"
    f"  --accent-s: {sat * 100:.0f}%;\n"
    f"  --accent-l: {light * 100:.0f}%;\n"
    f"  --accent-hsl: {hue:.0f}, {sat * 100:.0f}%, {light * 100:.0f}%;\n"
    f"  --interactive-accent-hsl: {hue:.0f}, {sat * 100:.0f}%, {light * 100:.0f}%;\n"
    f"  --achiri-on-accent: {on_accent};\n"
    f"  --achiri-on-danger: {on_danger};\n"
    "}\n"
    "/* achiri:accent-hsl:end */\n"
)

if snippet_path.exists():
    text = snippet_path.read_text()
    begin = "/* achiri:accent-hsl:begin"
    end = "/* achiri:accent-hsl:end */"
    if begin in text and end in text:
        head = text.split(begin)[0].rstrip() + "\n"
        tail = text.split(end, 1)[1].lstrip("\n")
        text = head + tail
else:
    text = ""

tmp_snippet = snippet_path.with_suffix(snippet_path.suffix + ".tmp")
snippet_path.parent.mkdir(parents=True, exist_ok=True)
tmp_snippet.write_text(text.rstrip() + "\n" + block)
tmp_snippet.replace(snippet_path)
PY

echo "wallust-obsidian: paleta sincronizada"
