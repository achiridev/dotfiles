-- ══════════════════════════════════════════════════════════════════════════════
--  plugin.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

-- Documentación: https://wiki.hypr.land/Plugins/Using-Plugins/

local plugin = {
	----------------------------------------------------------------------------
	-- CONFIGURACIÓN DE PLUGINS
	----------------------------------------------------------------------------
	plugin = {
		------------------------------------------------------------------------
		-- HYPRFOCUS (EFECTOS VISUALES AL CAMBIAR DE FOCO)
		------------------------------------------------------------------------
		hyprfocus = {
			enabled                 = true,
			animate_floating        = false,
			animate_workspacechange = false,
			focus_animation         = "flash",

			-- ───────── CURVAS BEZIER DE FOCO ─────────
			bezier = {
				{ "bezIn", 0.5, 0.0, 1.0, 0.5 },
				{ "bezOut", 0.0, 0.5, 0.5, 1.0 },
				{ "overshot", 0.05, 0.9, 0.1, 1.05 },
				{ "smoothOut", 0.36, 0, 0.66, -0.56 },
				{ "smoothIn", 0.25, 1, 0.5, 1 },
				{ "realsmooth", 0.28, 0.29, 0.69, 1.08 },
				{ "easeInOutBack", 0.68, -0.6, 0.32, 1.6 },
			},

			-- ───────── EFECTO FLASH ─────────
			flash = {
				flash_opacity = 0.7,
				in_bezier     = "bezIn",
				in_speed      = 0.5,
				out_bezier    = "bezOut",
				out_speed     = 3,
			},

			-- ───────── EFECTO SHRINK (ENCOGIMIENTO) ─────────
			shrink = {
				shrink_percentage = 0.99,
				in_bezier         = "easeInOutBack",
				in_speed          = 1.5,
				out_bezier        = "easeInOutBack",
				out_speed         = 3,
			},
		},
	},
}

return plugin
