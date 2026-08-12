-- ══════════════════════════════════════════════════════════════════════════════
--  binds.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

----------------------------------------------------------------------------
-- ATAJOS DE TECLADO ESTÁNDAR (BIND)
-- Documentación: https://wiki.hypr.land/Configuring/Basics/Binds/
----------------------------------------------------------------------------
local mainMod = "SUPER"

-- ───────── GENERAL ─────────
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + K", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
-- Workspace Overview (Quickshell) — reemplaza a hyprexpo
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("quickshell ipc call overview toggle"))

-- ───────── APPS ───────────
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"))

-- ───────── MOVER FOCO ─────────
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- ───────── CAMBIAR Y MOVER WORKSPACE (1 - 10) ─────────
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
	hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- ───────── SPECIAL WORKSPACE (SCRATCHPAD) ─────────
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic")) -- Tambien hay un "special"
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- ───────── NAVEGACIÓN CON RUEDA DEL MOUSE ─────────
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "+1" })) -- "e+1" cuando no hay mas -> retorna al inicio
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "-1" }))

-- ───────── NAVEGACIÓN RELATIVA ENTRE WORKSPACES ─────────
hl.bind(mainMod .. " + P", hl.dsp.focus({ workspace = "+1" }))
hl.bind(mainMod .. " + O", hl.dsp.focus({ workspace = "-1" }))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.move({ workspace = "+1" }))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.window.move({ workspace = "-1" }))

-- ───────── SCRIPTS DEL SISTEMA ───────────
hl.bind(" Print ", hl.dsp.exec_cmd("~/.local/bin/screenshot.sh"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("~/.local/bin/wallpaper-picker.sh"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/wallpaper.sh"))


----------------------------------------------------------------------------
-- ATAJOS DE MOUSE (BINDM)
-- Documentación: https://wiki.hypr.land/Configuring/Basics/Binds/#mouse-binds
----------------------------------------------------------------------------
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

----------------------------------------------------------------------------
-- TECLAS MULTIMEDIA Y BRILLO (BINDEL - REPETICIÓN Y LOCKED)
----------------------------------------------------------------------------
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -d intel_backlight set 10%+ && touch /tmp/qs-brightness-changed"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -d intel_backlight set 10%- && touch /tmp/qs-brightness-changed"), { locked = true, repeating = true })

----------------------------------------------------------------------------
-- CONTROL REPRODUCTOR MULTIMEDIA (BINDL - REPRODUCTOR EN BLOQUEO)
----------------------------------------------------------------------------
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

