// services/NotificationThemes.qml
// Registro de temas de notificación.
//
// Qué es un "tema": una forma de presentationsar una notificación concreta
// (batería, descarga, actualizaciones...) con su propio estilo y su propio
// timeout, sin tocar el resto del sistema de notificaciones.
//
// Cómo se activa: por `appName` (el `-a` de notify-send). Cero cambios en
// el script que emite:
//
//     notify-send -a "battery" -u critical "15%"
//
// Si el appName no está en el registro, la notificación usa el estilo
// normal (sin tema). Ver themes/README.md para crear uno nuevo.
pragma Singleton

import Quickshell

import qs.globals
import qs.themes

Singleton {
    id: root

    // appName → nombre del Singleton tema (sin la extensión .qml).
    // La clave DEBE coincidir con el `-a` del script.
    readonly property var registry: ({
        "battery": "BatteryTheme",
        "batteryFull": "BatteryFullTheme"
    })

    // Nombres aceptados. Evita que un app cualquiera active un tema por
    // accidente: si el appName no está aquí, se ignora.
    readonly property var allowed: Object.keys(root.registry)

    // Devuelve el tema para un appName, o null si no hay ninguno.
    function resolve(appName) {
        if (!appName) return null;
        const key = String(appName);
        if (Object.keys(root.registry).indexOf(key) < 0) return null;
        return root.themeFor(key);
    }

    // Instancia (o devuelve la ya creada) del tema registrado bajo `key`.
    function themeFor(key) {
        const name = root.registry[key];
        if (!name) return null;
        // Los temas son Singletons: se resuelven por su nombre en qs.themes.
        switch (name) {
        case "BatteryTheme":    return BatteryTheme;
        case "BatteryFullTheme": return BatteryFullTheme;
        default:                return null;
        }
    }

    // ¿Este appName tiene tema? (lo usa el toast para decidir la ruta)
    function has(appName) {
        return root.resolve(appName) !== null;
    }
}