#!/usr/bin/env bash

COLORS_FILE="$HOME/.cache/wallust/keyboard-colors"
REPO_DIR="$HOME/Descargas/acer-predator-turbo-and-rgb-keyboard-linux-module/facer_rgb.py"

hex_to_rgb() {
    local hex="${1#\#}"

    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    echo "$r $g $b"
}

mapfile -t COLORS < "$COLORS_FILE"

read R1 G1 B1 <<< "$(hex_to_rgb "${COLORS[0]}")"
read R2 G2 B2 <<< "$(hex_to_rgb "${COLORS[1]}")"
read R3 G3 B3 <<< "$(hex_to_rgb "${COLORS[2]}")"
read R4 G4 B4 <<< "$(hex_to_rgb "${COLORS[3]}")"

"$REPO_DIR" -m 0 -z 1 -cR "$R1" -cG "$G1" -cB "$B1"
"$REPO_DIR" -m 0 -z 2 -cR "$R2" -cG "$G2" -cB "$B2"
"$REPO_DIR" -m 0 -z 3 -cR "$R3" -cG "$G3" -cB "$B3"
"$REPO_DIR" -m 0 -z 4 -cR "$R4" -cG "$G4" -cB "$B4"
