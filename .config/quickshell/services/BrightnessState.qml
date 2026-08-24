pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // backends: "sysfs" (native backlight) · "ddcutil" (external monitors)
    property string backend: ""
    // sysfs device path when backend === "sysfs"
    property string devicePath: ""

    readonly property bool available: backend !== "" && (backend !== "sysfs" || devicePath !== "")

    property int maxBrightness: 1
    property int rawBrightness: 0

    readonly property real level: Math.max(0, Math.min(rawBrightness / Math.max(maxBrightness, 1), 1))
    readonly property int pctDisplay: Math.round(level * 100)

    // timestamp of the last locally-initiated change — lets the sysfs
    // watcher discard stale echoes that would snap sliders back mid-drag
    property real lastLocalSet: 0

    // probe once at startup: prefer sysfs backlight, else ddcutil.
    // laptops often expose several backlight devices (gpu + acpi + vendor)
    // where only one actually drives the panel — rank gpu-backed ones first,
    // or honor a QS_BACKLIGHT_DEVICE override
    Process {
        id: probe

        command: ["sh", "-c",
            'ov="$QS_BACKLIGHT_DEVICE"; '
            + 'if [ -n "$ov" ] && [ -e "/sys/class/backlight/$ov/brightness" ]; then '
            + 'echo "sys /sys/class/backlight/$ov"; exit 0; fi; '
            + 'for d in /sys/class/backlight/*; do '
            + '[ -e "$d/brightness" ] || continue; n=$(basename "$d"); '
            + 'case "$n" in *amdgpu*|*intel*|*nvidia*|*radeon*|*nouveau*) p=0 ;; *acpi*|*video*|*wmi*) p=8 ;; *) p=4 ;; esac; '
            + 'echo "dev $p $n $d"; '
            + 'done | sort -n | head -1; '
            + 'command -v ddcutil >/dev/null 2>&1 && { echo ddc; ddcutil -q getvcp 10 --brief | awk \'{print $4, $5}\'; }']
        running: true

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(/\s+/);
                if (parts[0] === "dev") {
                    root.backend = "sysfs";
                    root.devicePath = parts[3];
                    root.deviceName = parts[2];
                } else if (parts[0] === "sys") {
                    root.backend = "sysfs";
                    root.devicePath = parts[1];
                    root.deviceName = parts[1].split("/").pop();
                } else if (parts[0] === "ddc") {
                    root.backend = "ddc";
                    root.maxBrightness = 100;
                    if (parts.length >= 2)
                        root.rawBrightness = parseInt(parts[parts.length - 1]) || 0;
                }
            }
        }
    }

    property string deviceName: ""

    // when direct sysfs writes are rejected (missing setuid/udev perms) we
    // verify each commit landed and permanently switch to brightnessctl
    property bool preferCtl: false
    property int pendingTarget: -1

    function _ctlCmd(v) {
        const d = deviceName.replace(/'/g, "'\\''");
        return `command -v brightnessctl >/dev/null && brightnessctl -d '${d}' set ${v}%`;
    }

    Timer {
        id: verifyTimer

        interval: 800
        onTriggered: {
            if (root.pendingTarget < 0 || root.backend !== "sysfs")
                return;
            const want = Math.round(root.pendingTarget / 100 * root.maxBrightness);
            const tol = Math.max(1, Math.round(root.maxBrightness * 0.02));
            if (Math.abs(root.rawBrightness - want) > tol) {
                root.preferCtl = true;
                Quickshell.execDetached(["sh", "-c", root._ctlCmd(root.pendingTarget)]);
            }
            root.pendingTarget = -1;
        }
    }

    function setLevel(pct, commit = true) {
        if (!root.available)
            return; // no backend — refuse rather than fake values
        const v = Math.max(0, Math.min(Math.round(pct), 100));
        // optimistic update so sliders/OSD react instantly; watch/poll corrects it
        const raw = Math.round(v / 100 * root.maxBrightness);
        root.rawBrightness = raw;
        root.lastLocalSet = Date.now();
        if (!commit)
            return; // preview during drags — no process spawned per pixel
        if (root.backend === "sysfs") {
            const p = root.devicePath.replace(/'/g, "'\\''");
            const chain = root.preferCtl ? root._ctlCmd(v)
                : `if ! echo ${raw} > '${p}/brightness' 2>/dev/null; then ${root._ctlCmd(v)} 2>/dev/null; fi`;
            Quickshell.execDetached(["sh", "-c", chain]);
            root.pendingTarget = v;
            verifyTimer.restart();
        } else {
            // DDC/CI — VCP feature 0x10 is luminance (0-100 scale)
            Quickshell.execDetached(["ddcutil", "-q", "setvcp", "10", String(v)]);
        }
    }

    LazyLoader {
        loading: root.backend === "sysfs" && root.devicePath !== ""

        FileView {
            id: maxView

            path: root.devicePath + "/max_brightness"
            onLoaded: root.maxBrightness = parseInt(text()) || 1
        }

        FileView {
            id: curView

            path: root.devicePath + "/brightness"
            watchChanges: true
            onLoaded: {
                // discard reads that still predate our own write landing
                if (Date.now() - root.lastLocalSet < 400)
                    return;
                root.rawBrightness = parseInt(text()) || 0
            }
            // debounce: rapid write bursts would otherwise reload mid-write
            // and feed stale values back into the slider
            onFileChanged: reloadDebounce.restart()
        }

        Timer {
            id: reloadDebounce

            interval: 150
            onTriggered: curView.reload()
        }
    }

    // ddcutil has no file to watch — poll gently while anything cares
    property bool osdWatchersActive: false

    Timer {
        interval: 3000
        running: root.backend === "ddc" && root.osdWatchersActive
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            ddcCur.running = true;
        }
    }

    Process {
        id: ddcCur

        command: ["sh", "-c", "ddcutil -q getvcp 10 --brief | awk '{print $4}'"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const v = parseInt(data.trim());
                if (!isNaN(v)) {
                    root.maxBrightness = 100;
                    if (Date.now() - root.lastLocalSet >= 400)
                        root.rawBrightness = v;
                }
            }
        }
    }
}
