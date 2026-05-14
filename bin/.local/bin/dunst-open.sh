#!/usr/bin/env bash

set -euo pipefail

# ================================
# Script llamado por dunst al hacer click
# ================================

TARGET="${1:-}"

# Si no hay argumento, salir
[[ -z "$TARGET" ]] && exit 0

# Obtener nombre de la app que envió la notificación
APP_NAME="${DUNST_APP_NAME:-}"

# Extensiones de imagen permitidas
IMAGE_REGEX='\.png$|\.jpg$|\.jpeg$|\.webp$'

# ================================
# Caso 1: notificaciones de captura
# ================================
if [[ "$APP_NAME" == "captura" && "$TARGET" =~ $IMAGE_REGEX ]]; then
    # Intentar abrir con xdg-open
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$TARGET" >/dev/null 2>&1 &
        exit 0
    fi

    # Fallback a imv
    if command -v imv >/dev/null 2>&1; then
        imv "$TARGET" &
        exit 0
    fi
fi

# ================================
# Caso 2: todo lo demás (comportamiento normal)
# ================================
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$TARGET" >/dev/null 2>&1 &
fi
