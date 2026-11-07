# Portapapeles (Quickshell)

Gestor de historial del portapapeles integrado en la shell. Usa **cliphist**
como almacén persistente y **wl-clipboard** para restaurar. No hay servicio
nativo de historial en Quickshell 0.3.2: `Quickshell.clipboardText` solo
devuelve texto plano, así que el historial multimedia se delega en cliphist.

## Arquitectura por capas

```
utils/ClipboardUtils.js        lógica pura (parseo, tipos, búsqueda, metadatos)
services/ClipboardBackend.qml  procesos: clipboard-ctl (list/copy/text/thumb/…)
services/ClipboardService.qml  historial + filtro + preview + operaciones
globals/ClipboardState.qml     estado de sesión: abierto, query, selección
windows/clipboard/…            ventana por monitor (foco, backdrop, IPC)
widgets/clipboard/…            presentación sin lógica del portapapeles
```

- La UI **no** ejecuta `cliphist` ni `wl-copy`.
- `ClipboardService` **no** importa nada de `widgets/`.
- `ClipboardUtils.js` no importa QML/Quickshell y se puede probar con Node.
- `bin/.local/bin/clipboard-ctl` es el único adaptador con el sistema.

## Flujo de datos

```
wl-paste --watch clipboard-store → cliphist (DB persistente)
Quickshell → ClipboardBackend → clipboard-ctl → cliphist / wl-copy / magick
```

DB: `~/.cache/cliphist/db` (valor por defecto de cliphist; **no se migra**).
Config: `config/cliphist/.config/cliphist/config` (500 entradas, preview 1024).
Caché de miniaturas: `~/.cache/quickshell/clipboard/thumbs/<id>.png`.

## Contrato de una entrada

`ClipboardUtils.parseList()` devuelve objetos con:

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | string | ID de cliphist (string para no perder precisión) |
| `preview` / `summary` | string | Preview saneado de una línea |
| `kind` | string | `text` \| `image` \| `binary` |
| `format` | string | `PNG`, `JPEG`, `PDF`, `ZIP`… (`""` en texto) |
| `bytes` | int | Tamaño en bytes (0 si se desconoce) |
| `width` / `height` | int | Solo imágenes |
| `sizeLabel` | string | Tamaño legible (`12.4 MiB`) |
| `kindLabel` | string | `Texto`, `Imagen`, `Binario` |
| `meta` | string | Línea de metadatos para la UI |
| `search` | string | Texto normalizado para búsqueda |

## API de servicios

`ClipboardService` (singleton):

- Datos: `entries`, `filtered`, `query`, `loading`, `ready`, `error`,
  `totalCount`, `imageCount`, `filteredCount`.
- Preview: `selectedId`, `preview { id, kind, text, image, mime, loading, error }`.
- Acciones: `refresh()`, `setQuery()`, `clearQuery()`, `select()`,
  `copy()`, `remove()`, `clearAll()`, `clearPreview()`.
- Señales: `copied(id)`, `removed(id)`, `wiped()`, `refreshed()`.

`ClipboardState` (singleton): `open`, `selectedIndex`, `currentEntry`,
`confirmClear`; `toggle()`, `openWindow()`, `close()`, `setQuery()`,
`move()`, `movePage()`, `activate()`, `deleteCurrent()`, `requestClear()`.

`ClipboardBackend` (singleton): solo procesos y señales. No tomar decisiones
de negocio aquí.

## Rediseñar la interfaz

Para cambiar por completo la apariencia **sin tocar la lógica**:

1. **Tokens**: edita `ClipboardStyle.qml` (colores, tamaños, radios, tiempos).
2. **Composición**: reemplaza `ClipboardView.qml` por tu propio layout. La
   ventana solo necesita un componente con `focusSearch()` y acceso a
   `ClipboardState` / `ClipboardService`.
3. **Piezas**: los widgets (`ClipboardSearchBar`, `ClipboardList`,
   `ClipboardRow`, `ClipboardPreview`, `ClipboardEmptyState`,
   `ClipboardFooter`) son stateless: reciben propiedades y emiten señales.
   Puedes sustituirlos uno a uno, pasar de lista a grid o añadir animaciones.
4. **Ventana**: `ClipboardWindow.qml` solo gestiona monitor, foco, backdrop e
   IPC. Si tu diseño necesita otra superficie, cambia la ventana o crea otra y
   apunta el `Loader` de `shell.qml` a ella.

Los colores derivan de `AppTheme`, así que el cambio de fondo de Wallust se
refleja en vivo. No se añadió plantilla de Wallust para el portapapeles.

## Atajos

| Tecla | Acción |
|---|---|
| `SUPER+V` | Abrir/cerrar el portapapeles |
| Escribir | Filtrar en vivo |
| `↑` / `↓` | Navegar (circular) |
| `PgUp` / `PgDn` | Navegar por páginas |
| `Ctrl+Home` / `Ctrl+End` | Primera / última entrada |
| `Enter` o clic | Copiar y cerrar |
| `Supr` (buscador vacío) / `Ctrl+Supr` | Eliminar entrada |
| `Esc` | Limpiar búsqueda; si está vacía, cerrar |

`SUPER+SHIFT+V` conserva el toggle de ventana flotante.

## IPC

```bash
quickshell ipc call clipboard toggle
quickshell ipc call clipboard open
quickshell ipc call clipboard close
quickshell ipc call clipboard refresh
quickshell ipc call clipboard clear
```

## Rendimiento

- Todo proceso externo es asíncrono (`Process` + `StdioCollector`); nada
  bloquea el hilo de QML.
- La lista no decodifica imágenes por fila: la miniatura se genera solo para
  la entrada seleccionada, con debounce (80 ms) y caché en disco.
- Texto de preview acotado a 32 KB; imágenes con `sourceSize`, carga async y
  sin mipmaps.
- `ListView` con `reuseItems` y `cacheBuffer` acotado.
- Las miniaturas huérfanas (cliphist cambia el ID al deduplicar) se podan en
  cada `list`, así la caché no crece sin control.
- Sin polling: se refresca al abrir, al copiar, al borrar y al limpiar.
- Los duplicados los gestiona cliphist (`max-dedupe-search 300`).

## Dependencias

Ya instaladas en el sistema: `cliphist`, `wl-clipboard`, `imagemagick`,
`file`, `iconv`. No se añadió ninguna dependencia nueva.

## Pruebas manuales sugeridas

1. Copiar texto, abrir con `SUPER+V`, buscar, `Enter`, pegar.
2. Copiar captura de pantalla → miniatura → restaurar y pegar.
3. Copiar imagen desde navegador → `clipboard-store` debe guardar la imagen.
4. Copiar archivo desde Thunar → debe guardar el URI, no la miniatura; al
   restaurar, `clipboard-ctl copy` lo devuelve como `text/uri-list`.
5. Copiar el mismo texto dos veces → una sola entrada, movida arriba.
6. Eliminar una entrada, limpiar todo y reabrir.
7. Reiniciar Quickshell y comprobar persistencia.
8. Multimonitor: abrir en el monitor enfocado.

## Añadir/quitar del Panel de Control

`ControlState.clipboardEnabled` y `SettingsService.clipboardEnabled` controlan
el `Loader` de `shell.qml`. Desactivarlo destruye la UI, pero **cliphist sigue
guardando historial** porque es un servicio systemd independiente.
