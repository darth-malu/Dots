import Quickshell.Io
import QtQuick

Item {
    id: root

    // Stores the previous calculation state (the "prev" struct in your C code)
    property var lastStats: ({
            "total": 0,
            "idle": 0
        })
    property string cpuUsageString: "0.00%"

    FileView {
        id: cpuFile
        path: "file:///proc/stat"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            cpuFile.reload();
            root.processCpuData(cpuFile.text());
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

            root.cpuUsageString = utilization.toFixed(0) + "%";
            // console.log(`CPU Usage: ${root.cpuUsageString}`);
        }

        // prev = curr
        lastStats = {
            "total": currentTotalSum,
            "idle": currentIdleAll
        };
    }
}
