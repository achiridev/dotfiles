#!/bin/bash

# Esperar a que Hyprland y Wayland estén listos
sleep 1

# 1. Exportar el entorno a DBus y systemd
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

# 2. Levantar el target específico de Hyprland (esto arrastrará automáticamente a graphical-session.target)
systemctl --user start hyprland-session.target

# No suele ser necesario iniciar el portal manualmente si el target arranca bien,
# pero lo dejamos como red de seguridad.
systemctl --user start xdg-desktop-portal.service
