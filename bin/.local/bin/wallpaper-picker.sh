#!/usr/bin/env bash

# ===== CONFIG =====
DB="$HOME/.local/share/waywallen/waywallen-v2.db"
ROFI_THEME="$HOME/dotfiles/config/rofi/.config/rofi/themes/wallpaper.rasi"
WALLPAPER_SCRIPT="$HOME/.local/bin/wallpaper.sh"

CACHE_DIR="$HOME/.cache/wallpaper_previews"
mkdir -p "$CACHE_DIR"

# ===== OBTENER ITEMS DE WAYWALLEN (wallpaper-engine / workshop) =====
# Cada línea: nombre<TAB>id<TAB>preview_completo
list_items() {
    sqlite3 -readonly -separator $'\t' "$DB" "
        SELECT i.display_name, i.id, l.path || '/' || i.preview_path
          FROM item i JOIN library l ON l.id = i.library_id
         WHERE i.plugin_id = 4
         ORDER BY lower(i.display_name) COLLATE NOCASE;"
}

# ===== GENERAR MENU DE ROFI =====
# Cada línea: "<id>\0display\x1f<nombre>\x1fmeta\x1f<nombre>\x1ficon\x1f<preview>"
# - El texto de la fila es el id: rofi lo devuelve al seleccionar (determinista,
#   no depende del nombre -> resuelve wallpapers con el mismo display_name).
# - display/meta: muestran el nombre y permiten filtrar por él.
# - icon: preview de la imagen.
menu() {
    local name id preview ext cached
    while IFS=$'\t' read -r name id preview; do
        [[ -z "$name" ]] && continue

        # cache de preview (mejora rendimiento y maneja rutas de Steam)
        ext="${preview##*.}"
        cached="$CACHE_DIR/${id}.${ext,,}"
        if [[ ! -f "$cached" ]] || [[ "$preview" -nt "$cached" ]]; then
            cp "$preview" "$cached" 2>/dev/null || continue
        fi

        printf '%s\x00display\x1f%s\x1fmeta\x1f%s\x1ficon\x1f%s\n' \
            "$id" "$name" "$name" "$cached"
    done < <(list_items)
}

# ===== MAIN =====
main() {
    local choice

    # rofi devuelve directamente el id del item (texto de la fila)
    choice=$(menu | rofi -i -dmenu -config "$ROFI_THEME" \
        -theme-str 'configuration { hover-select: false; }')

    [[ -z "$choice" ]] && exit 0

    [[ "$choice" =~ ^[0-9]+$ ]] || { echo "Selección inválida: $choice" >&2; exit 1; }

    "$WALLPAPER_SCRIPT" "$choice"
}

# Evitar duplicados de rofi
pkill rofi 2>/dev/null

main
