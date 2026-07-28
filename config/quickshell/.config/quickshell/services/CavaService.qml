pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property int barCount: 60
    property var bars: new Array(barCount).fill(0)

    property Process cavaProcess: Process {
        id: cavaProcess
        running: false

        // command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/config"]

        stdout: SplitParser {
            splitMarker: "\n"
            // splitMarker por defecto = "\n", coincide con frame_delimiter=10
            onRead: data => {
                if (!data) return

                // Limpiamos y separamos por ";"
                const cleanData = data.trim();
                if (cleanData.length === 0) return;

                const values = cleanData.split(";")
                    .filter(v => v !== "")
                    .map(v => parseInt(v, 10) || 0);

                if (values.length === root.barCount) {
                    root.bars = Array.from(values);
                }
            }
        }
    }

    Component.onCompleted: {
        // Asignamos el comando para garantizar que $HOME esté resuelto
        const configPath = Quickshell.env("HOME") + "/.config/cava/config";
        cavaProcess.command = ["cava", "-p", configPath];
        cavaProcess.running = true;
    }
}
