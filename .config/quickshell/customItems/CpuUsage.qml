import Quickshell.Io
import QtQuick

Item {
    id: root
    property var stat

    FileView {
        id: cpuFile
        // path: Qt.resolvedUrl("/proc/stat")
        path: "file:///proc/stat"
        // onLoaded: {}
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

        // Get the first line (aggregate CPU)
        let lines = rawText.split('\n');
        let cpuLine = lines[0].split(/\s+/);

        // cpuLine[1] = user, [2] = nice, [3] = system, [4] = idle...
        let idle = parseInt(cpuLine[4]);

        // Remove first element (cpu) -> see /proc/stat first line then decompose the rest of the array into one value
        let used = cpuLine.slice(1).reduce((a, b) => a + parseInt(b || 0), 0);

        console.log(`Herein lies the total cumulative cpu usage: ${used}`);
    }
}
