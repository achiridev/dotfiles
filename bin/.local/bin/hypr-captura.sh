#!/usr/bin/env bash
set -euo pipefail

#########################################
######### AHORA MISMO NADIE LO LLAMA ##############
###########################################

# Aseguramos un PATH útil (Hyprland puede no tener ~/.local/bin)
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOG="$HOME/.local/share/hypr-captura.log"
mkdir -p "$(dirname "$LOG")"
echo "---- $(date +'%F %T') - hypr-captura invoked by $(id -un) ----" >>"$LOG"

# Verificamos dependencias
for cmd in grim slurp wl-copy notify-send; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: falta $cmd" >>"$LOG"
    notify-send "hypr-captura: falta $cmd" "Instala: pacman -S ${cmd}" || true
    exit 1
  fi
done

# Carpeta donde guardamos las capturas
mkdir -p "$HOME/Imágenes/Capturas"

# Selección con slurp (si cancelas, salimos sin error)
geom="$(slurp)" || { echo "slurp cancelado o error" >>"$LOG"; exit 0; }
[ -n "$geom" ] || { echo "geom vacío" >>"$LOG"; exit 0; }

# Archivo de salida
file="$HOME/Imágenes/Capturas/captura-$(date +%Y-%m-%d_%H-%M-%S).png"
echo "geom: $geom -> file: $file" >>"$LOG"

# Captura → guarda y copia al portapapeles
if grim -g "$geom" - | tee "$file" | wl-copy --type image/png; then
  notify-send -i "$file" "📸 Captura guardada" "$file" || true
  echo "OK saved: $file" >>"$LOG"
else
  echo "ERROR: grim falló" >>"$LOG"
  notify-send "hypr-captura: error al guardar" "Mira $LOG" || true
  exit 1
fi

# Opcional: abrir panel de swaync si está disponible (no rompe si no existe)
swaync-client -op 2>>"$LOG" || true
