# Temas de notificación

Un **tema** le da a una notificación concreta su propio estilo y su propio
comportamiento, sin tocar el resto del sistema de notificaciones.

Ejemplo real: el aviso de batería baja se queda en pantalla hasta que lo
cierras tú, con el color según la franja y una barra de nivel.

## Cómo se activa

Por `appName`, que es el `-a` de `notify-send`. **No hay que cambiar nada más:**

```bash
notify-send -a "battery" -u critical "⚠ Batería baja" "Batería al 15%"
```

Si el `appName` no está registrado, la notificación usa el estilo normal.
Ningún otro script se ve afectado.

## Crear un tema nuevo: 5 pasos

### 1. Crear el archivo

`config/quickshell/.config/quickshell/themes/MiTema.qml`

```qml
pragma Singleton

import qs.globals
import qs.services

Singleton {
    id: theme

    // ─── Estilo (lo mínimo obligatorio) ───
    readonly property color accent: AppTheme.warning
    readonly property int timeoutMs: AppTheme.notificationsTimeoutNormal * 1000

    // ─── Textos de reserva (si la notificación no los manda) ───
    readonly property string defaultSummary: "Mi aviso"
    readonly property string defaultBody: "detalle aquí"

    // ─── Opcionales, con valor por defecto ───
    readonly property bool showGauge: false
    readonly property real gaugeValue: 0
}
```

### 2. Registrarlo en el mapa

`config/quickshell/.config/quickshell/services/NotificationThemes.qml`

```qml
readonly property var registry: ({
    "battery": "BatteryTheme",
    "batteryFull": "BatteryFullTheme",
    "miTema": "MiTema"          // ← la clave es el appName
})
```

### 3. Añadirlo al `switch` de resolución

En el **mismo archivo**, dentro de `themeFor()`:

```qml
case "MiTema": return MiTema;
```

> El `switch` es a propósito: si el nombre no está en el registro, no se
> instancia nada. Así un app no puede activar un tema por accidente.

### 4. Reiniciar y probar

```bash
systemctl --user restart quickshell.service
notify-send -a "miTema" -u normal "Prueba" "cuerpo"
```

No hace falta `stow` ni tocar Hyprland: Quickshell lee el symlink de
`~/.config/quickshell`, que apunta al repo.

## Propiedades que puede usar un tema

| Propiedad | Tipo | Para qué |
|---|---|---|
| `accent` | `color` | Línea de urgencia, medidor, botón de enviar |
| `timeoutMs` | `int` | `0` = nunca expira (solo se cierra a mano) |
| `defaultSummary` | `string` | Título si la notificación no trae |
| `defaultBody` | `string` | Cuerpo si la notificación no trae |
| `icon` | `string` | Icono propio (ruta o nombre) |
| `showGauge` | `bool` | Mostrar la barra de medidor |
| `gaugeValue` | `real` | Relleno de la barra, `0.0`–`1.0` |
| `badgeText` | `string` | Etiqueta corta (opcional) |

## Datos en vivo desde el daemon

Lo interesante: el tema **no está limitado a lo que el script mande por
D-Bus**. Puede leer los singletons que ya existen:

```qml
import qs.services

readonly property int percentage: BatteryService.percentage
readonly property string timeLeft: BatteryService.timeRemainingText
readonly property string title: WorkspacesService.currentWorkspace
```

Disponibles en `qs.services`: `BatteryService`, `AudioService`, `MprisService`,
`PowerService`, `SystemStatsService`, `TimeService`, `WallpaperService`…

Así el aviso de batería muestra el nivel **real** de UPower, aunque el script
se haya ejecutado hace dos minutos.

## Notas prácticas

- **Los Singletons son globales**: un tema es una sola instancia para todo el
  shell. No pongas estado mutable que cambie por notificación; solo valores
  derivados (`readonly property`).
- **`timeoutMs: 0` y el centro**: con timeout 0 la notificación no se cierra
  sola y se queda en el popup. El usuario la quita con el ✕ o con "limpiar".
- **El sonido no lo maneja el tema.** Si quieres que suene, sigue en el
  script con `papyly`; el tema solo controla lo visual.
- **Si tu script ya spammea**, ponle un guard como hace
  `notificacion_bateria.sh` con `/tmp/battery_20_warned`. Así el aviso no se
  repite cada vez que el timer pasa.