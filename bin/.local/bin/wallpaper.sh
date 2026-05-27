#!/usr/bin/env bash

set -e

WALLPAPER_DIR="$HOME/dotfiles/wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"

# Selección de wallpaper
if [[ -z "$1" ]]; then
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n 1)
else
    WALLPAPER="$1"
fi

# Evitar repetir el mismo wallpaper
if [[ -f "$CACHE_FILE" && "$(cat "$CACHE_FILE")" == "$WALLPAPER" ]]; then
    echo "Wallpaper ya aplicado, omitiendo..."
    exit 0
fi

echo "$WALLPAPER" > "$CACHE_FILE"

echo "Aplicando wallpaper: $WALLPAPER"

# 1. Wallpaper (swww/awww)
awww img "$WALLPAPER" \
    --transition-type wipe \
    --transition-angle 30 \
    --transition-duration 1.2 \
    --transition-fps 60

# 2. Generar colores
echo "Generando paleta..."
wallust --skip-sequences -d ~/dotfiles/config/wallust/.config/wallust run "$WALLPAPER"

# 3. Recargar apps

# Kitty
kitty @ set-colors -a ~/.config/kitty/colors.conf
pkill -USR1 kitty 2>/dev/null || true

# Rofi
pkill rofi 2>/dev/null || true # No necesario

# Waybar
pkill -SIGUSR2 waybar 2>/dev/null || true

# SwayNC
swaync-client --reload-config 2>/dev/null || true

# Hyprland
hyprctl reload

echo "Tema aplicado correctamente"
