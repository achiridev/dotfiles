#!/usr/bin/env bash

# ===== CONFIG =====
WALL_DIR="$HOME/dotfiles/wallpapers"
ROFI_THEME="$HOME/dotfiles/config/rofi/.config/rofi/themes/wallpaper.rasi"

# ===== ROFI =====
rofi="rofi -i -dmenu -config $ROFI_THEME"
rofi_cmd="rofi -x11 -dmenu -theme ${ROFI_THEME} -theme-str ${rofi_override}"
# el -x11 hace que no que fije el hover sobre rofi

# ===== CACHE (opcional pero recomendado) =====
CACHE_DIR="$HOME/.cache/wallpaper_previews"
if [ ! -d "${CACHE_DIR}" ] ; then
        mkdir -p "${CACHE_DIR}"
    fi

# ===== GENERAR MENU =====
menu() {
    while IFS= read -r -d '' file; do
        name=$(basename "$file")

        # cache preview (opcional: mejora rendimiento con muchas imágenes)
        preview="$CACHE_DIR/$name"

        if [[ ! -f "$preview" ]]; then
            cp "$file" "$preview"
        fi

        printf "%s\x00icon\x1f%s\n" "$name" "$preview"

    done < <(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) -print0)
}

# ===== MAIN =====
main() {
    choice=$(menu | $rofi_cmd)

    [[ -z "$choice" ]] && exit 0

    # Buscar archivo real
    selected=$(find "$WALL_DIR" -type f -iname "$choice" -print -quit)

    [[ -z "$selected" ]] && exit 1

    # Ejecutar tu script real
    ~/.local/bin/wallpaper.sh "$selected"
}

# Evitar duplicados de rofi
pkill rofi 2>/dev/null

main
