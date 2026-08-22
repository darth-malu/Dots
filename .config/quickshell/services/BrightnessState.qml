pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // first backlight-capable device (DDC-only setups report unavailable)
    property string devicePath: ""
    readonly property bool available: devicePath !== ""

    property int maxBrightness: 1
    property int rawBrightness: 0

    readonly property real level: Math.max(0, Math.min(rawBrightness / Math.max(maxBrightness, 1), 1))
    readonly property int pctDisplay: Math.round(level * 100)

    function setLevel(pct) {
        const v = Math.max(0, Math.min(Math.round(pct), 100));
        // optimistic update so sliders/OSD react instantly; sysfs watch corrects it
        root.rawBrightness = Math.round(v / 100 * root.maxBrightness);
        Quickshell.execDetached(["sh", "-c", `command -v brightnessctl >/dev/null && brightnessctl set ${v}%`]);
    }

    Process {
        id: probe

        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -e \"$d/brightness\" ] && echo \"$d\" && break; done"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const p = data.trim();
                if (p.length > 0)
                    root.devicePath = p;
            }
        }
    }

    LazyLoader {
        loading: root.devicePath !== ""

        FileView {
            id: maxView

            path: root.devicePath + "/max_brightness"
            onLoaded: root.maxBrightness = parseInt(text()) || 1
        }

        FileView {
            id: curView

            path: root.devicePath + "/brightness"
            watchChanges: true
            onLoaded: root.rawBrightness = parseInt(text()) || 0
            onFileChanged: reload()
        }
    }
}
