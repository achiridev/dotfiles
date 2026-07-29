-- ══════════════════════════════════════════════════════════════════════════════
--  hyprland.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

--------------------------------------------------------------------------------
-- MONITORES
-- Documentación: https://wiki.hypr.land/Configuring/Basics/Monitors/
--------------------------------------------------------------------------------

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
--[[
hl.monitor({
    output = "DP-1",
    mode = "1920x1080@144",
    position = "0x0",
    scale = 1,
})
]]

--------------------------------------------------------------------------------
-- ARCHIVOS DE CONFIGURACIÓN MODULARES (SOURCES)
-- Documentación: https://wiki.hypr.land/Configuring/Start/#require
--------------------------------------------------------------------------------
colors = require("modules.colors")
require("modules.apps")
require("modules.autostart")
require("modules.env")
require("modules.permissions")
require("modules.look")
require("modules.animations")
require("modules.input")
require("modules.devices")
require("modules.binds")
require("modules.windowrules")
-- require("modules.plugin")

