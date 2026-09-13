-- ══════════════════════════════════════════════════════════════════════════════
--  autostart.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

----------------------------------------------------------------------------
-- SERVICIOS Y APLICACIONES AL INICIAR (EXEC-ONCE)
-- Documentación: https://wiki.hypr.land/Configuring/Basics/Autostart/
----------------------------------------------------------------------------
hl.on("hyprland.start", function ()

	-- Bar, wallpaper, notificaciones
	-- La barra vive en la unit systemd `quickshell.service` (env de sesión
	-- completo + Restart=always), que se auto-resucita en cualquier crash.
	-- El launch vía hyprland.lua inyecta capacidades ambientales que rompen
	-- quickshell (Hyprland discussion #14844), por eso no se lanza directo.
	hl.exec_cmd("systemctl --user start quickshell.service")
	hl.exec_cmd("swaync")
	hl.exec_cmd("waywallen --no-ui")
	-- hl.exec_cmd("awww-daemon")
	-- hl.exec_cmd("waybar")

	-- Portapapeles y gestor de archivos
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("thunar --daemon")

	-- Hypr
	hl.exec_cmd("hypridle")

end)
