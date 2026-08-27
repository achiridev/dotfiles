#!/usr/bin/env bash

set -e

DB="$HOME/.local/share/waywallen/waywallen-v2.db"
CACHE_FILE="$HOME/.cache/current_wallpaper"

DAEMON="org.waywallen.waywallen.Daemon"
OBJ="/org/waywallen/waywallen/Daemon"
IFACE="org.waywallen.waywallen.Daemon1"

WAYWALLEN_DIR="$HOME/dotfiles/config/wallust/.config/wallust"

# ----------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------
resolve_item() {
    # $1 = id or display name. Prints "id<TAB>full_preview_path"
    local q="${1//\'/\'\'}"
    sqlite3 -readonly "$DB" \
        "SELECT i.id || char(9) || (l.path || '/' || i.preview_path)
           FROM item i JOIN library l ON l.id = i.library_id
          WHERE i.plugin_id = 4
            AND (i.id = '$q' OR lower(i.display_name) = lower('$q'))
          LIMIT 1;"
}

current_id() {
    busctl --user get-property "$DAEMON" "$OBJ" "$IFACE" CurrentWallpaperId 2>/dev/null \
        | sed -n 's/^s "\(.*\)"$/\1/p'
}

apply_by_id() {
    # $1 = item id. Returns the D-Bus reply on stdout, errors to stderr.
    busctl --user call "$DAEMON" "$OBJ" "$IFACE" ApplyById s "$1"
}

# ----------------------------------------------------------------------
# Argument handling
# ----------------------------------------------------------------------
MODE="$1"

# Convenience modes for keybindings
if [[ "$MODE" == "next" || "$MODE" == "previous" ]]; then
    busctl --user call "$DAEMON" "$OBJ" "$IFACE" "${MODE^}" >/dev/null
    ID=$(current_id)
    [[ -z "$ID" ]] && { echo "No se pudo obtener el wallpaper actual" >&2; exit 1; }
    echo "$ID" > "$CACHE_FILE"
    echo "Wallpaper en cola: $ID"
    exit 0
fi

# $1 may be an item id or a display name
if [[ -z "$MODE" ]]; then
    echo "Uso: $0 <id|nombre|next|previous> [preview opcional]" >&2
    exit 1
fi

ITEM=$(resolve_item "$MODE")
if [[ -z "$ITEM" ]]; then
    # Fallback: tratar ARG (o MODE) como una ruta a imagen local (preview antigua)
    if [[ -f "$MODE" ]]; then
        echo "Aviso: '$MODE' no es un item de waywallen; usando wallust con esa imagen" >&2
        WALLUST_IMG="$MODE"
        ID=""
    else
        echo "Item no encontrado en waywallen: $MODE" >&2
        exit 1
    fi
else
    ID="${ITEM%%	*}"
    PREVIEW="${ITEM#*	}"
    WALLUST_IMG="$PREVIEW"
fi

# Evitar repetir el mismo wallpaper
CURRENT=$(current_id)
if [[ -n "$ID" && -n "$CURRENT" && "$CURRENT" == "$ID" ]]; then
    echo "Wallpaper ya aplicado, omitiendo..."
    exit 0
fi

# ----------------------------------------------------------------------
# 1. Aplicar wallpaper con waywallen
# ----------------------------------------------------------------------
if [[ -n "$ID" ]]; then
    echo "Aplicando wallpaper (id $ID):"
    apply_by_id "$ID"
else
    echo "No se aplica wallpaper: solo regenerando colores desde $WALLUST_IMG"
fi

[[ -n "$ID" ]] && echo "$ID" > "$CACHE_FILE"

# ----------------------------------------------------------------------
# 2. Generar colores con wallust (desde el preview del item)
# ----------------------------------------------------------------------
if [[ -n "$WALLUST_IMG" && -f "$WALLUST_IMG" ]]; then
    echo "Generando paleta desde $WALLUST_IMG ..."
    wallust --skip-sequences -d "$WAYWALLEN_DIR" run "$WALLUST_IMG"
else
    echo "Aviso: no hay imagen de preview válida; no se regenera la paleta" >&2
fi

# ----------------------------------------------------------------------
# Extra. Cambiar colores del teclado
# ----------------------------------------------------------------------
~/dotfiles/bin/.local/bin/wallust-keyboard.sh

# ----------------------------------------------------------------------
# 3. Recargar apps
# ----------------------------------------------------------------------

# Kitty
kitty @ set-colors -a ~/.config/kitty/colors.conf 2>/dev/null || true
pkill -USR1 kitty 2>/dev/null || true

# Rofi
pkill rofi 2>/dev/null || true

# Waybar
pkill -SIGUSR2 waybar 2>/dev/null || true

# SwayNC (lo recarga el hook de wallust, redundancia por si acaso)
pkill -SIGUSR2 swaync 2>/dev/null || true

# Hyprland
hyprctl reload 2>/dev/null || true

echo "Tema aplicado correctamente"
