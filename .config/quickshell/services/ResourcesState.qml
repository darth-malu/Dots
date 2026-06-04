pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var lastStats: ({
            "total": 0,
            "idle": 0
        })
    property int cpuUsageString

    property int cpuPercent
    property real cpuFreq
    property real cpuTemp

    property int gpuPercent
    property string gpuFreq
    property real gpuFans
    property real gpuTemp

    property int memPercent
    property real memTotal: 0
    property real memUsed: 0
    property int swapPercent
    property real swapTotal: 0
    property real swapUsed: 0
    // property string darth_pool
    property string btrfsDevice
    property string mediaDisks: ""
    property string allDisks: ""
    property string allDisksPending: ""
    property bool resourcesVisible: false

    FileView {
        id: cpuUsageFile
        path: "file:///proc/stat"
    }

    FileView {
        id: gpuBusyPercent
        path: "file:///sys/class/drm/card1/device/gpu_busy_percent"
    }

    FileView {
        id: memoryFile
        path: "file:///proc/meminfo"
    }

    Timer {
        id: cpuUsage
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuUsageFile.reload();
            root.processCpuData(cpuUsageFile.text());
            memoryFile.reload();
            root.processMemoryData(memoryFile.text());
            gpuBusyPercent.reload();
            root.gpuPercent = parseInt(gpuBusyPercent.text()) || 0;
            process_cpu_temp.running = true;
        }
    }

    function processMemoryData(rawText) {
        if (!rawText)
            return;

        let lines = rawText.split('\n');

        // RAM
        let memTotalKB = parseInt(lines[0].split(/\s+/)[1]);
        let memAvailableKB = parseInt(lines[2].split(/\s+/)[1]);
        let used = memTotalKB - memAvailableKB;
        let percent = (used / memTotalKB) * 100;
        root.memPercent = Math.round(percent);
        root.memTotal = +(memTotalKB / 1024 / 1024).toFixed(1);
        root.memUsed = +(used / 1024 / 1024).toFixed(1);

        // Swap
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i];
            if (line.startsWith("SwapTotal:")) {
                let swapTotalKB = parseInt(line.split(/\s+/)[1]) || 0;
                root.swapTotal = +(swapTotalKB / 1024 / 1024).toFixed(1);
                let swapFreeLine = lines[i + 1];
                if (swapFreeLine && swapFreeLine.startsWith("SwapFree:")) {
                    let swapFreeKB = parseInt(swapFreeLine.split(/\s+/)[1]) || 0;
                    let swapUsedKB = swapTotalKB - swapFreeKB;
                    root.swapUsed = +(swapUsedKB / 1024 / 1024).toFixed(1);
                    root.swapPercent = swapTotalKB > 0 ? Math.round((swapUsedKB / swapTotalKB) * 100) : 0;
                }
                break;
            }
        }
    }

    function processCpuData(rawText) {
        if (!rawText)
            return;

        // Split by line and then by whitespace
        let lines = rawText.split('\n');
        let cpuLine = lines[0].trim().split(/\s+/);

        // Map columns based on your C struct:
        // cpuLine[1]=user, [2]=nice, [3]=system, [4]=idle, [5]=iowait, [6]=irq...
        let user = parseInt(cpuLine[1] || 0);
        let nice = parseInt(cpuLine[2] || 0);
        let system = parseInt(cpuLine[3] || 0);
        let idle = parseInt(cpuLine[4] || 0);
        let iowait = parseInt(cpuLine[5] || 0);
        let irq = parseInt(cpuLine[6] || 0);
        let softirq = parseInt(cpuLine[7] || 0);
        let steal = parseInt(cpuLine[8] || 0);

        // C Logic: s->idle_all = s->idle + s->iowait;
        let currentIdleAll = idle + iowait;

        // C Logic: s->total_sum = user + nice + system + idle + iowait + irq + softirq + steal;
        let currentTotalSum = user + nice + system + idle + iowait + irq + softirq + steal;

        // Calculate Deltas (curr - prev)
        let totalDelta = currentTotalSum - lastStats.total;
        let idleDelta = currentIdleAll - lastStats.idle;

        if (totalDelta > 0) {
            // C Logic: (double)(total_delta - idle_delta) / total_delta * 100.0
            let usedDelta = totalDelta - idleDelta;
            let utilization = (usedDelta / totalDelta) * 100.0;

            // root.cpuUsageString = utilization.toFixed(2) + "%";
            root.cpuUsageString = Math.round(utilization);
        }

        // prev = curr
        lastStats = {
            "total": currentTotalSum,
            "idle": currentIdleAll
        };
    }

    Process {
        id: process_cpu_temp
        running: false
        command: ["sh", "-c", "$HOME/.config/quickshell/scripts/cpuTemp.sh"]
        stdout: SplitParser {
            onRead: data => cpuTemp = Math.round(data / 1000)
        }
    }

    Process {
        id: disk_usage
        // TODO: notification on lowIdsk - persistent properties
        running: false
        command: ["sh", "-c", "findmnt -n -o AVAIL /"]
        stdout: SplitParser {
            onRead: data => btrfsDevice = data
        }
    }

    Process {
        id: mediaCheck
        running: false
        command: ["sh", "-c", "findmnt -n -l -o TARGET,AVAIL,SIZE --raw 2>/dev/null | grep '^/media/' || true"]
        stdout: SplitParser {
            onRead: data => {
                if (data.length > 0)
                    mediaDisks += data + "\n"
            }
        }
    }

    Process {
        id: allDisksProcess
        running: false
        command: ["sh", "-c", "df -h -x tmpfs -x devtmpfs -x squashfs -x overlay --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2"]
        stdout: SplitParser {
            onRead: data => root.allDisksPending += data + "\n"
        }
    }

    Timer {
        id: diskTimer
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: () => {
            mediaDisks = "";
            root.allDisksPending = "";
            mediaCheck.running = true;
            allDisksProcess.running = true;
            disk_usage.running = true;
            diskSwapTimer.restart();
        }
    }

    Timer {
        id: diskSwapTimer
        interval: 250
        running: false
        repeat: false
        onTriggered: () => {
            if (root.allDisksPending.trim().length > 0)
                root.allDisks = root.allDisksPending;
        }
    }


}
