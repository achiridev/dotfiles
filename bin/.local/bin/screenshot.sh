#!/usr/bin/env bash

set -euo pipefail

DIR="$HOME/Imágenes/Capturas"
mkdir -p "$DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILE="$DIR/captura-$TIMESTAMP.png"

wayfreeze --hide-cursor &
FREEZE_PID=$!

cleanup() {
    kill "$FREEZE_PID" 2>/dev/null || true
    wait "$FREEZE_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Dar tiempo a que wayfreeze capture el frame
sleep 0.15

# ─────────────────────────────────────────────
# 1. Selección de región (mejor control de error)
# ─────────────────────────────────────────────
GEOM=$(slurp 2>/dev/null) || exit 0

# Si el usuario cancela (vacío)
[ -z "$GEOM" ] && exit 0

# ─────────────────────────────────────────────
# 2. Captura
# ─────────────────────────────────────────────
if ! grim -g "$GEOM" - | tee "$FILE" | wl-copy --type image/png; then
    notify-send "❌ Error" "No se pudo tomar la captura"
    rm -f "$FILE"
    exit 1
fi

# ─────────────────────────────────────────────
# 3. Descongelar la pantalla antes de notificar
# ─────────────────────────────────────────────
cleanup

# ─────────────────────────────────────────────
# 4. Notificación con acciones
# ─────────────────────────────────────────────
ACTION=$(notify-send \
    -a "captura" \
    -i "$FILE" \
    -A "open=Abrir" \
    -A "edit=Editar" \
    -A "delete=Eliminar" \
    "Captura guardada" "$FILE" || true)

# ─────────────────────────────────────────────
# 5. Acciones
# ─────────────────────────────────────────────
case "$ACTION" in
    open)
        imv "$FILE" & disown
        ;;
    edit)
        swappy -f "$FILE"
        ;;
    delete)
        rm -f "$FILE"
        notify-send "🗑️ Eliminado" "$FILE"
        ;;
esac
