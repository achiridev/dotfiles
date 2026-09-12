-- ══════════════════════════════════════════════════════════════════════════════
--  autostart.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

----------------------------------------------------------------------------
-- SERVICIOS Y APLICACIONES AL INICIAR (EXEC-ONCE)
-- Documentación: https://wiki.hypr.land/Configuring/Basics/Autostart/
----------------------------------------------------------------------------
hl.on("hyprland.start", function ()

	-- Bar, wallpaper, notificaciones
	-- quickshell-respawn relanza la barra solo si crasheó (señal >= 128);
	-- un kill/SIGTERM o error de config la deja muerta para diagnosticar.
	hl.exec_cmd("quickshell-respawn")
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
