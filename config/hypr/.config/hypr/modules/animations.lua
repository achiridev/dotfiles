-- ══════════════════════════════════════════════════════════════════════════════
--  animations.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

----------------------------------------------------------------------------
-- ANIMACIONES
-- Documentación: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
----------------------------------------------------------------------------

hl.curve("expressiveFastSpatial", {
	type = "bezier",
	points = {{0.42, 1.67}, {0.21, 0.90}}
})
hl.curve("expressiveSlowSpatial", {
	type = "bezier",
	points = {{0.39, 1.29}, {0.35, 0.98}}
})
hl.curve("expressiveDefaultSpatial", {
	type = "bezier",
	points = {{0.38, 1.21}, {0.22, 1.00}}
})
hl.curve("emphasizedDecel", {
	type = "bezier",
	points = {{0.05, 0.7}, {0.1, 1}}
})
hl.curve("emphasizedAccel", {
	type = "bezier",
	points = {{0.3, 0}, {0.8, 0.15}}
})
hl.curve("standardDecel", {
	type = "bezier",
	points = {{0, 0}, {0, 1}}
})
hl.curve("menu_decel", {
	type = "bezier",
	points = {{0.1, 1}, {0, 1}}
})
hl.curve("menu_accel", {
	type = "bezier",
	points = {{0.52, 0.03}, {0.72, 0.08}}
})
hl.curve("stall", {
	type = "bezier",
	points = {{1, -0.1}, {0.7, 0.85}}
})


-- windows
hl.animation({
	leaf = "windowsIn",
	enabled = true,
	speed = 3,
	bezier = "emphasizedDecel",
	style = "popin 80%"
})
hl.animation({
	leaf = "fadeIn",
	enabled = true,
	speed = 3,
	bezier = "emphasizedDecel"
})
hl.animation({
	leaf = "windowsOut",
	enabled = true,
	speed = 2,
	bezier = "emphasizedDecel",
	style = "popin 90%"
})
hl.animation({
	leaf = "fadeOut",
	enabled = true,
	speed = 2,
	bezier = "emphasizedDecel"
})
hl.animation({
	leaf = "windowsMove",
	enabled = true,
	speed = 3,
	bezier = "emphasizedDecel",
	style = "slide"
})
hl.animation({
	leaf = "border",
	enabled = true,
	speed = 10,
	bezier = "emphasizedDecel"
})

-- layers
hl.animation({
	leaf = "layersIn",
	enabled = true,
	speed = 2.7,
	bezier = "emphasizedDecel",
	style = "popin 93%"
})
hl.animation({
	leaf = "layersOut",
	enabled = true,
	speed = 2.4,
	bezier = "menu_accel",
	style = "popin 94%"
})
-- fade
hl.animation({
	leaf = "fadeLayersIn",
	enabled = true,
	speed = 0.5,
	bezier = "menu_decel"
})
hl.animation({
	leaf = "fadeLayersOut",
	enabled = true,
	speed = 2.7,
	bezier = "stall"
})
-- workspaces
hl.animation({
	leaf = "workspaces",
	enabled = true,
	speed = 7,
	bezier = "menu_decel",
	style = "slide"
})
-- specialWorkspace
hl.animation({
	leaf = "specialWorkspaceIn",
	enabled = true,
	speed = 2.8,
	bezier = "emphasizedDecel",
	style = "slidevert"
})
hl.animation({
	leaf = "specialWorkspaceOut",
	enabled = true,
	speed = 1.2,
	bezier = "emphasizedAccel",
	style = "slidevert"
})
-- zoom
hl.animation({
	leaf = "zoomFactor",
	enabled = true,
	speed = 3,
	bezier = "standardDecel"
})

--[[
local animations = {
	enabled = true,

	------------- CURVAS BEZIER -----------------
	bezier = {
		{ "smooth", 0.5, 0.5, 0.4, 1.1 },
		{ "easeOut", 0.23, 1, 0.32, 1 },
		{ "easeInOut", 0.65, 0.05, 0.36, 1 },
		{ "snappy", 0.15, 0, 0.1, 1 },
		{ "easeOutQuint", 0.23, 1, 0.32, 1 },
	},

	------------- REGLAS DE ANIMACIÓN ------------
	animation = {
		-- Ventanas
		{ "windows", 1, 5, "easeOut", "popin 85%" },
		{ "windowsIn", 1, 4, "easeOut", "popin 85%" },
		{ "windowsOut", 1, 1.4, "easeOutQuint", "popin 70%" },

		-- Desvanecimiento (Fades)
		{ "fade", 1, 2.5, "easeOut" },
		{ "fadeIn", 1, 1.8, "easeOut" },
		{ "fadeOut", 1, 1.2, "easeOut" },

		-- Capas (Barras, Notificaciones, etc.)
		{ "layers", 1, 3, "easeOut", "fade" },

		-- Espacios de Trabajo (Workspaces)
		{ "workspaces", 1, 2.2, "smooth" },
	},
}
]]
