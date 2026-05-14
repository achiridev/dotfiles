#!/usr/bin/env bash

DIR="$HOME/Imágenes/Capturas"
mkdir -p "$DIR"

FILE="$DIR/captura-$(date +%Y-%m-%d_%H-%M-%S).png"

# Si el usuario cancela el slurp, salir limpiamente
if ! grim -g "$(slurp)" - | tee "$FILE" | wl-copy --type image/png 2>/dev/null; then
    rm -f "$FILE"
    exit 0
fi

ACTION=$(notify-send \
    -a "captura" \
    -i "$FILE" \
    -A "open:Abrir imagen" \
    "Captura guardada" "$FILE" || true)

if [ "$ACTION" = "0" ]; then
    # disown desacopla xdg-open del proceso padre para que funcione en Wayland
    # xdg-open "$FILE" & disown
    imv "$FILE" & disown
fi