#!/usr/bin/env bash

# Genera miniaturas estáticas (16:9) de los previews de waywallen para el
# grid del picker Quickshell. Jugada idempotente: omite las ya generadas.
# Salida: $HOME/.cache/wallpaper_previews/thumbs/<id>.jpg

set -euo pipefail

DB="$HOME/.local/share/waywallen/waywallen-v2.db"
CACHE="$HOME/.cache/wallpaper_previews/thumbs"
W=384
H=216
MISSING="$CACHE/missing.jpg"

[[ -d "$CACHE" ]] || mkdir -p "$CACHE"

# Placeholder 16:9 para los items cuyo preview no está en disco (comprimidos
# sin descargar en Steam). Reutilizable para todos los casos.
if [[ ! -f "$MISSING" ]]; then
    magick -size "${W}x${H}" xc:"#1d2129" \
        -fill "#303643" -draw "rectangle 0,$((H/2-24)) $((W)),$((H/2+24))" \
        -fill "#454d5e" -draw "rectangle 0,$((H/2-6)) $((W)),$((H/2+6))" \
        "$MISSING" 2>/dev/null || true
fi

while IFS=$'\t' read -r id preview; do
    [[ -n "$id" ]] || continue

    out="$CACHE/${id}.jpg"
    [[ -f "$out" ]] && continue

    if [[ -n "$preview" && -f "$preview" ]]; then
        src="${preview}[0]"
    else
        src="$MISSING"
    fi

    magick "$src" \
        -thumbnail "${W}x${H}^" -gravity center -extent "${W}x${H}" \
        -quality 82 "$out" || true
done < <(sqlite3 -readonly -separator $'\t' "$DB" "
    SELECT i.id, l.path || '/' || i.preview_path
      FROM item i JOIN library l ON l.id = i.library_id
     WHERE i.plugin_id = 4 AND i.preview_path LIKE 'steamapps/workshop/%';")