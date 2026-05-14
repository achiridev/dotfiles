#!/bin/bash

BAT_PATH="/sys/class/power_supply/BAT1"
LEVEL=$(cat "$BAT_PATH/capacity")
STATUS=$(cat "$BAT_PATH/status")

# Archivo para evitar spam de notificaciones
LOW_STATE="/tmp/battery_20_warned"
HIGH_STATE="/tmp/battery_80_warned"

############################
# BATERIA BAJA (≤20%)
############################
# Solo avisar si está descargando y es <= 20%
if [ "$STATUS" = "Discharging" ] && [ "$LEVEL" -le 20 ] && [ ! -f "$LOW_STATE" ]; then
    notify-send -a "Bateria" -u critical "⚠ Batería baja" "Batería al ${LEVEL}%"
    paplay  ~/.config/dunst/sounds/sourcream.wav
    touch "$LOW_STATE"
fi
# Si vuelve a subir de 20%, se reinicia el aviso
if [ "$LEVEL" -gt 20 ]; then
    rm -f "$LOW_STATE"
fi

############################
# ⚡ BATERÍA ALTA (≥80%)
############################
if [ "$STATUS" = "Charging" ] && [ "$LEVEL" -ge 80 ] && [ ! -f "$HIGH_STATE" ]; then
    notify-send -a "BateriaAlta" -u normal "⚡ Batería al 80%" "Desconecta el cargador"
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga
    touch "$HIGH_STATE"
fi
# Reset del aviso alto
if [ "$LEVEL" -lt 80 ]; then
    rm -f "$HIGH_STATE"
fi
