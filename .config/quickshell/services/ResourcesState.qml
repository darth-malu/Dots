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
    // property string darth_pool
    property string btrfsDevice
    property string mediaDisks: ""
    property string allDisks: ""
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
            process_cpu_temp.running = true;
        }
    }

    function processMemoryData(rawText) {
        if (!rawText)
            return;

        let lines = rawText.split('\n');
        let memTotalLine = lines[0];
        let memAvailableLine = lines[2];

        // split by spaces to get only the number
        let memTotalKB = parseInt(memTotalLine.split(/\s+/)[1]);
        let memAvailableKB = parseInt(memAvailableLine.split(/\s+/)[1]);

        // calculate used ram - difference total - avail
        let used = memTotalKB - memAvailableKB;
        let percent = (used / memTotalKB) * 100;
        root.memPercent = Math.round(percent);
        root.memTotal = +(memTotalKB / 1024 / 1024).toFixed(1);
        root.memUsed = +(used / 1024 / 1024).toFixed(1);
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
        command: ["sh", "-c", "df -h -x tmpfs -x devtmpfs -x squashfs -x overlay --output=target,size,used,avail 2>/dev/null | tail -n +2"]
        stdout: SplitParser {
            onRead: data => allDisks += data + "\n"
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
            allDisks = "";
            mediaCheck.running = true;
            allDisksProcess.running = true;
            disk_usage.running = true;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        /* triggeredOnStart: true */
        onTriggered: () => {
            process_cpu_temp.running = true;
        }
    }
}
