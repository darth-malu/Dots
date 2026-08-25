// Inside your Singleton { ... }

property string memPercent: "0%"

FileView {
    id: memFile
    path: "/proc/meminfo"
}

// Update this in your existing Timer's onTriggered
function processMemData(rawText) {
    if (!rawText) return;
    
    let lines = rawText.split('\n');
    let total = 0;
    let available = 0;

    for (let line of lines) {
        if (line.startsWith("MemTotal:")) {
            total = parseInt(line.split(/\s+/)[1]);
        } else if (line.startsWith("MemAvailable:")) {
            available = parseInt(line.split(/\s+/)[1]);
            break; // We have what we need
        }
    }

    if (total > 0) {
        let used = total - available;
        let percent = (used / total) * 100;
        root.memPercent = percent.toFixed(0) + "%";
    }
}
