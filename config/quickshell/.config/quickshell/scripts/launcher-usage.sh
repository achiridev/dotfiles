#!/usr/bin/env bash

# scripts/launcher-usage.sh
# Muestra de uso del launcher Gear: acumula lanzamientos por .desktop path.
#   add <path>   → incrementa el contador de <path> y reescribe el TSV
# El archivo lo consume list-apps.sh para ordenar la lista por frecuencia:
# las apps más usadas ocupan el hub / diente superior al abrir el launcher.
# TSV: desktopPath<SEP>count   (en $XDG_CACHE_HOME/quickshell/)
set -u

USAGE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/launcher-usage.tsv"
SEP=$'\t'

cmd="${1:-}"
arg="${2:-}"
[ "$cmd" = "add" ] && [ -n "$arg" ] || exit 0

mkdir -p "$(dirname "$USAGE_FILE")"
[[ -f "$USAGE_FILE" ]] || : > "$USAGE_FILE"

tmp="$USAGE_FILE.tmp.$$"
awk -F "$SEP" -v path="$arg" '
    {
        lines[$1] = $2
        if ($1 == path) {
            lines[$1] = lines[$1] + 1
            seen = 1
        }
    }
    END {
        for (k in lines) print k "\t" lines[k]
        if (!seen) print path "\t1"
    }
' "$USAGE_FILE" > "$tmp" 2>/dev/null && mv -f "$tmp" "$USAGE_FILE" || rm -f "$tmp"