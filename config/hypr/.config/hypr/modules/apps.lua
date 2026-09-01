-- ══════════════════════════════════════════════════════════════════════════════
--  apps.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

----------------------------------------------------------------------------
-- PROGRAMAS PRINCIPALES
-- Documentación: https://wiki.hypr.land/Configuring/Basics/Variables/
----------------------------------------------------------------------------
terminal    = "~/.config/hypr/scripts/run-first-available.sh 'kitty' 'alacritty'"
fileManager = "~/.config/hypr/scripts/run-first-available.sh 'kitty yazi' 'thunar'"
browser     = "~/.config/hypr/scripts/run-first-available.sh 'zen-browser' 'brave' 'firefox'"
codeEditor  = "~/.config/hypr/scripts/run-first-available.sh 'idea' 'code'"
-- Launcher principal (Quickshell Gear) y respaldo max-power (rofi).
launcher    = "quickshell ipc call launcher toggle"
menu        = "~/.config/hypr/scripts/run-first-available.sh 'rofi -show drun'"
