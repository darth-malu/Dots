pragma Singleton

import Quickshell
import Quickshell.Io

import QtQuick

Singleton {
    id: root

    // INTERNET
    Timer {
        id: dataTimer
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.diskDataPending = "";
            if (BatteryState.available)
                brightnessProcess.running = true;
        }
    }

    // HOSTNAME
    FileView {
        id: hostFile
        // path: "file:///proc/sys/kernel/hostname"
        path: Qt.resolvedUrl("/proc/sys/kernel/hostname")
    }

    property string hostName: {
        var raw = hostFile.text().trim();
        return raw.length > 0 ? raw : "unknown";
    }

    Process {
        id: brightnessProcess
        running: false
        command: ["sh", "-c", "val=$(brightnessctl get 2>/dev/null) && max=$(brightnessctl max 2>/dev/null) && echo $((val * 100 / max))"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim());
                if (!isNaN(v))
                    root.brightness = v;
            }
        }
    }
}
