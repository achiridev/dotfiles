#!/usr/bin/env bash

# Gestión de carpetas del picker de wallpapers (Quickshell).
# Persistencia client-side (no toca la DB de waywallen):
#   { "folders": [ { "name": "...", "icon": "...", "ids": [ "...", ... ] } ] }
# Uso:
#   wallpaper-folders.sh init                      # crea el archivo si falta
#   wallpaper-folders.sh new   <nombre>
#   wallpaper-folders.sh rm    <nombre>
#   wallpaper-folders.sh rename <nombre> <nuevo>
#   wallpaper-folders.sh add   <nombre> <id>
#   wallpaper-folders.sh remove <nombre> <id>

set -euo pipefail

FILE="${WALLPAPER_FOLDERS_FILE:-$HOME/.config/quickshell/wallpaper-folders.json}"

usage() {
    echo "uso: $0 {init|new|rm|rename|add|remove} ..." >&2
    exit 1
}

ensure_file() {
    [[ -d "$(dirname "$FILE")" ]] || mkdir -p "$(dirname "$FILE")"
    [[ -s "$FILE" ]] || printf '%s\n' '{"folders":[{"name":"Primarios","icon":"","ids":[]}]}' > "$FILE"
}

write_json() {
    printf '%s\n' "$1" > "$FILE"
}

[[ $# -ge 1 ]] || usage
CMD="$1"; shift

case "$CMD" in
    init)
        ensure_file
        ;;
    new)
        [[ $# -eq 1 ]] || usage
        ensure_file
        prog='.folders += [{"name":$n,"icon":"","ids":[]}]'
        write_json "$(jq --arg n "$1" "$prog" "$FILE")"
        ;;
    rm)
        [[ $# -eq 1 ]] || usage
        ensure_file
        prog='.folders |= map(select(.name != $n))'
        write_json "$(jq --arg n "$1" "$prog" "$FILE")"
        ;;
    rename)
        [[ $# -eq 2 ]] || usage
        ensure_file
        prog='.folders |= map(if .name == $o then (.name = $n) else . end)'
        write_json "$(jq --arg o "$1" --arg n "$2" "$prog" "$FILE")"
        ;;
    add)
        [[ $# -eq 2 ]] || usage
        ensure_file
        prog='(. as $r | any(.folders[]; .name == $n)) as $has
            | if $has then
                .folders |= map(if .name == $n and (.ids | index($i) | not) then (.ids += [$i]) else . end)
              else
                .folders += [{"name":$n,"icon":"","ids":[$i]}]
              end'
        write_json "$(jq --arg n "$1" --arg i "$2" "$prog" "$FILE")"
        ;;
    remove)
        [[ $# -eq 2 ]] || usage
        ensure_file
        prog='.folders |= map(if .name == $n then (.ids |= map(select(. != $i))) else . end)'
        write_json "$(jq --arg n "$1" --arg i "$2" "$prog" "$FILE")"
        ;;
    *)
        usage
        ;;
esac