-- ══════════════════════════════════════════════════════════════════════════════
--  look.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

----------------------------------------------------------------------------
-- CONFIGURACIÓN GENERAL
-- Documentación: https://wiki.hypr.land/Configuring/Basics/Variables/
----------------------------------------------------------------------------

hl.config({
	general = {
		gaps_in  = 5,
		gaps_out = 15,
		border_size = 2,

		col = {
			active_border   = { colors = {colors.color4, colors.color5}, angle = 45 },
			inactive_border = colors.color0,
		},

		resize_on_border = true,
		allow_tearing = false, -- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
		layout = "dwindle",
	},

	decoration = {
		rounding       = 8,
		rounding_power = 2,

		active_opacity   = 0.98,
		inactive_opacity = 0.85,
		fullscreen_opacity = 1.0,

		shadow = {
			enabled      = true,
			range        = 4,
			render_power = 3,
			color        = 0x1a1a1aee,
		},

		blur = {
			enabled   = true,
			size      = 3,
			passes    = 1,
			vibrancy  = 0.1696,
		},
	},

	animations = {
		enabled = true,
		-- workspace_wraparound = true,
	},

	misc = {
		disable_hyprland_logo = true,
	},

	dwindle = {
		preserve_split = true,
	},

	master = {
		new_status = "master",
	},
})

---------------------------------------------------------------------------
-- LAYER RULES — Blur detrás del workspace overview (namespace de la capa
-- "quickshell:overview-blur" definido en windows/overview/Overview.qml).
-- https://wiki.hypr.land/Configuring/Decorations/#blur
---------------------------------------------------------------------------
hl.layer_rule({
	name = "overview-blur",
	match = { namespace = "^quickshell:overview-blur$" },
	blur = true,
	ignore_alpha = 0.2,
})

-- wayfreeze (captura): sin animación de entrada/salida de la capa
hl.layer_rule({
	name = "wayfreeze-noanim",
	match = { namespace = "^wayfreeze$" },
	no_anim = true,
})

hl.layer_rule({
	name = "wlogout",
	match = { namespace = "^wlogout$" },
	no_anim = true,
})
