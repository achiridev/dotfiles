-- ══════════════════════════════════════════════════════════════════════════════
--  windowrules.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

----------------------------------------------------------------------------
-- REGLAS DE VENTANAS (WINDOW RULES)
-- Documentación Window Rules: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- Documentación Workspace Rules: https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
----------------------------------------------------------------------------

-- ───────── REGLAS GENERALES Y COMPORTAMIENTO ─────────
local suppressMaximizeRule = hl.window_rule({
	-- Ignore maximize requests from all apps.
	name  = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name  = "fix-xwayland-drags",
	match = {
		class      = "^$",
		title      = "^$",
		xwayland   = true,
		float      = true,
		fullscreen = false,
		pin        = false,
	},

	no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
	name  = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move  = "20 monitor_h-120",
	float = true,
})

-- ───────── QUICKSHELL · CAMBIO DE MODO DE ENERGÍA (battery-mode) ─────────
-- Kitty que lanza battery-mode desde el panel de batería: ahí pide la
-- contraseña de sudo y se cierra sola al terminar (o al pulsar una tecla si
-- el script falló).
hl.window_rule({
	name  = "qs-battery-mode",
	match = { class = "^qs-battery-mode$" },

	size   = "520 240",
	center = true,
	float  = true,
})

-- ───────── QUICKSHELL · PANEL FLOTANTE DE BATERÍA ─────────
-- Ventana real (xdg) del panel de batería de quickshell: flota y centrada al
-- abrirse; movible con Super+drag como cualquier ventana.
hl.window_rule({
	name  = "qs-battery-panel",
	match = { title = "^qs-battery-panel$" },

	float  = true,
	center = true,
})

--[[
-- ───────── JETBRAINS INTELLIJ IDEA (SIN TRANSPARENCIA / OPACIDAD TOTAL) ─────────
hl.window_rule({
	name = "idea-opacity",
	match = {
		class = "^(jetbrains-idea-ce)$",
		float = false,
	},
	opacity = "1.0 1.0",
})
hl.window_rule({
	name = "idea-opaque",
	match = {
		class = "^(jetbrains-idea-ce)$",
	},
	opaque = true,
})

-- ───────── CONFIGURACIÓN DE MOSAICO PARA KITTY ─────────
hl.window_rule({
	name = "kitty-tile",
	match = {
		class = "^(kitty)$",
		float = false,
	},
})
]]
