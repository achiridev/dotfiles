-- ══════════════════════════════════════════════════════════════════════════════
--  env.lua — achiridev
-- ══════════════════════════════════════════════════════════════════════════════

----------------------------------------------------------------------------
-- VARIABLES DE ENTORNO (CURSOR Y TEMAS)
-- Documentación: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
----------------------------------------------------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "rose-pine-hyprcursor")

-- Qt usa el platform theme GTK3: lee el tema de iconos/estilo de GTK
-- (Papirus-Dark vía gsettings). Sin esto Qt resuelve iconos contra el
-- fallback "hicolor" y apps con icono solo en temas reales (brave, hwloc,
-- network-wired…) dan "Could not load icon" en Quickshell/launcher.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

-- Qt 6.10+ con el theme gtk3 intenta registrar su app-id contra
-- xdg-desktop-portal, pero la conexión D-Bus ya tiene uno asociado → WARN
-- "Failed to register with host portal" al arrancar quickshell. Es una
-- doble-registración interna de Qt, sin impacto funcional; se silencia solo
-- esa categoría de Qt.
hl.env("QT_LOGGING_RULES", "qt.qpa.services=false")

-- hl.env("HYPRCURSOR_SIZE", "24")
-- env = HYPRCURSOR_THEME,rose-pine-hyprcursor
