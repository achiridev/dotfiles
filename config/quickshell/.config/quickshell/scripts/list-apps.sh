#!/usr/bin/env bash

# scripts/list-apps.sh
# Escanea los directorios XDG de aplicaciones (.desktop) y emite un TSV:
#   desktopPath<SEP>name<SEP>icon<SEP>exec<SEP>keywords<SEP>terminal
# (una línea por app).
# Lo consume AppModel.qml (launcher Gear) vía Process/StdioCollector.
# Sin dependencias externas (awk + sort).
set -u

SEP=$'\t'

parse_desktop() {
    local file="$1"
    # awk por archivo: descarta Hidden/NoDisplay/Type!=Application y extrae
    # Name/Icon/Exec/Keywords/Terminal. No maneja continuaciones de línea (\)
    # a propósito: son raras en los .desktop reales.
    awk -F= '
        /^Type/ {
            sub(/^Type[[:space:]]*=/, "", $0)
            gsub(/[[:space:]]/, "", $0)
            if ($0 != "Application") skip = 1
        }
        /^Hidden/ { sub(/^Hidden[[:space:]]*=/, "", $0); gsub(/[[:space:]]/, "", $0); if ($0 == "true") skip = 1 }
        /^NoDisplay/ { sub(/^NoDisplay[[:space:]]*=/, "", $0); gsub(/[[:space:]]/, "", $0); if ($0 == "true") skip = 1 }
        /^Name=/ { sub(/^Name[[:space:]]*=/, ""); if (!sawName) { sawName = 1; name = $0 } }
        /^Name\[/ { next }
        /^Icon=/ { sub(/^Icon[[:space:]]*=/, ""); icon = $0 }
        /^Exec=/ { sub(/^Exec[[:space:]]*=/, ""); exec = $0 }
        /^Keywords=/ { sub(/^Keywords[[:space:]]*=/, ""); kw = $0 }
        /^Keywords\[/ { next }
        /^Terminal=/ { sub(/^Terminal[[:space:]]*=/, ""); gsub(/[[:space:]]/, "", $0); term = ($0 == "true" ? "1" : "0") }
        END {
            if (skip || !exec || !name) exit 0
            gsub(/%[fFuUdDnNickvm]/, "", exec)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", exec)
            gsub(/^"|"$/, "", exec)
            gsub(/[[:space:]]*;[[:space:]]*/, ";", kw)
            gsub(/^;|;$/, "", kw)
            printf "%s\t%s\t%s\t%s\t%s\t%s\n", "'"$file"'", name, (icon ? icon : "application-x-executable"), exec, kw, term
        }
    ' "$file"
}

# Directorios del sistema primero; los del usuario se procesan después para
# que prevalezcan en el dedup (se conserva la última ocurrencia).
# OJO: XDG_DATA_DIRS usa ':' como separador (partir por espacios no vale).
dirs=()
IFS=: read -r -a sys_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for d in "${sys_dirs[@]}"; do
    [[ -n "$d" ]] && dirs+=("$d/applications")
done
dirs+=("${XDG_DATA_HOME:-$HOME/.local/share}/applications")

# Dedup y ordenación:
# 1) awk en dos pasadas: conserva la última línea por nombre (case-insensitive)
#    manteniendo el orden de aparición de esa última ocurrencia.
# 2) sort por campo 2 (Name), case-insensitive y por bytes para estabilidad.
# 3) orden por USO (launcher-usage.sh): frecuencia desc (empate → nombre asc),
#    de modo que las apps más usadas quedan al frente (hub / diente superior).
USAGE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/launcher-usage.tsv"
{
    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for desk in "$dir"/*.desktop; do
            # El glob sigue symlinks (los .desktop de Flatpak son symlinks al
            # archivo real dentro del sandbox); descartamos rotos con -f.
            [[ -f "$desk" ]] || continue
            parse_desktop "$desk"
        done
    done
} | awk -F "$SEP" '
    { key = tolower($2); line[key] = $0; order[++n] = key }
    END {
        # reversa: la primera ocurrencia aquí = última en el input
        for (i = n; i >= 1; i--)
            if (!seen[order[i]]++) out[++m] = line[order[i]]
        for (i = m; i >= 1; i--) print out[i]
    }
' | sort -f -t "$SEP" -k2,2 \
  | awk -v usage_file="$USAGE_FILE" 'BEGIN {
        while ((getline lu < usage_file) > 0) { split(lu, a, "\t"); cnt[a[1]] = a[2] + 0 }
    } {
        rank = sprintf("%010d", 999999999 - (cnt[$1] + 0))
        print rank "\t" tolower($2) "\t" $0
    }' \
  | sort -t "$SEP" -k1,1 -k2,2 \
  | cut -d "$SEP" -f 3-