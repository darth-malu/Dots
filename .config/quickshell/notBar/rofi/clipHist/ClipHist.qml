pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.notBar.rofi

// Clipboard history browser backed by cliphist (omarchy-style):
// · type to filter, Enter copies the real payload via `cliphist decode`
//   (text AND images survive — no more raw-list-line copying)
// · Delete removes the selected entry from the history
Rofi {
    id: root
    visible: RofiState.toggleClipHist

    // every raw `cliphist list` line ("id\tpreview")
    property var entries: []

    // search-filtered view feeding the list
    readonly property var filteredEntries: {
        const q = root.searchField.toLowerCase();
        if (q.length === 0)
            return entries;
        return entries.filter(e => e.toLowerCase().includes(q));
    }

    modelIngest: filteredEntries

    delegateIngest: LauncherDelegate {
        required property var modelData

        iconUrl: ""
        app: TextClipHistDelegate {}
    }

    // shell-quote a raw entry so it can travel through printf safely
    function shQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    // ── load the history every time the launcher opens ──
    onVisibleChanged: {
        if (visible) {
            root.focusSearch();
            listProcess.running = true;
        }
    }

    Process {
        id: listProcess

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.length > 0);
                root.entries = lines;
            }
        }
    }

    onClipChosen: entry => {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s' " + shQuote(entry) + " | cliphist decode | wl-copy"]);
        Quickshell.execDetached(["notify-send", "-a", "Clipboard", "-t", "1500", "\uf0c5  Copied to clipboard"]);
    }

    onClipDeleted: entry => {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s' " + shQuote(entry) + " | cliphist delete"]);
        root.entries = root.entries.filter(e => e !== entry);
    }
}
