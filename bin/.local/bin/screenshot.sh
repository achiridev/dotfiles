#!/usr/bin/env bash

set -euo pipefail

DIR="$HOME/Imágenes/Capturas"
mkdir -p "$DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILE="$DIR/captura-$TIMESTAMP.png"

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
# 3. Notificación con acciones
# ─────────────────────────────────────────────
ACTION=$(notify-send \
    -a "captura" \
    -i "$FILE" \
    -A "open=Abrir" \
    -A "edit=Editar" \
    -A "delete=Eliminar" \
    "Captura guardada" "$FILE" || true)

# ─────────────────────────────────────────────
# 4. Acciones
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
