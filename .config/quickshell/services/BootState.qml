pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// EFI boot entries via efibootmgr — lets the logout overlay schedule the NEXT
// reboot into another boot entry (e.g. Windows). Listing is read-only; arming
// a BootNext (efibootmgr -n <num>, a one-shot "boot this once") goes through
// pkexec so the polkit prompt handles elevation, then reboots immediately.
Singleton {
    id: root

    property bool ready: false // listing fully parsed
    property bool busy: lst.running || act.running
    property string error: ""
    property var entries: [] // [{num, active, label}]
    property string current: "" // BootCurrent number
    property string next: "" // armed BootNext number ("" = none)
    property string wip: "" // boot number being armed ("" = idle)

    // re-run efibootmgr and rebuild the entry list
    function refresh() {
        if (lst.running)
            return;
        lst.tick++;
        lst.buf = "";
        root.ready = false;
        root.error = "";
        lst.running = true;
    }

    // arm BootNext for one boot, then reboot into it (pkexec → polkit prompt)
    function bootOnce(num) {
        if (!num || act.running)
            return;
        root.wip = num;
        root.error = "";
        act.tick++;
        act.mode = "bootOnce";
        act.buf = "";
        act.cmd = "pkexec efibootmgr -n " + num + " 2>&1 && systemctl reboot || true";
        act.running = true;
    }

    // cancel an armed BootNext without rebooting
    function clearNext() {
        if (act.running)
            return;
        root.error = "";
        act.tick++;
        act.mode = "clearNext";
        act.buf = "";
        act.cmd = "pkexec efibootmgr -N 2>&1 || true";
        act.running = true;
    }

    // ── listing (read-only) ──
    Process {
        id: lst

        property int tick: 0
        property string buf: ""

        running: false
        command: ["sh", "-c", "efibootmgr --unicode 2>&1 || true"]

        stdout: SplitParser {
            onRead: data => lst.buf += data + "\n"
        }

        onExited: root._parseList(true)
    }

    // ── arming / clearing BootNext ──
    Process {
        id: act

        property int tick: 0
        property string mode: ""
        property string cmd: ""
        property string buf: ""

        running: false
        command: ["sh", "-c", act.cmd]

        stdout: SplitParser {
            onRead: data => act.buf += data + "\n"
        }

        onExited: exitCode => {
            root.wip = "";
            const raw = act.buf.trim();
            if (act.mode === "bootOnce") {
                if (exitCode === 0) {
                    const m = /BootNext:\s*([0-9A-Fa-f]{4})/.exec(raw);
                    root.next = m ? m[1] : "";
                    root.error = "";
                    root.ready = true;
                } else {
                    root.error = raw.length > 0 ? raw : "could not set BootNext (elevation cancelled?)";
                }
            } else if (act.mode === "clearNext") {
                if (exitCode === 0) {
                    root.next = "";
                    root.error = "";
                } else {
                    root.error = raw.length > 0 ? raw : "could not clear BootNext";
                }
            }
        }
    }

    function _parseList(fromList) {
        const raw = (fromList ? lst.buf : act.buf).trim();
        const out = [];
        let current = "";
        let bootNext = "";
        let bootOrder = "";
        for (const line of raw.split("\n")) {
            const t = line.trim();
            if (t.length === 0)
                continue;
            const bm = /^Boot([0-9A-Fa-f]{4})(\*?)\s+(.+)$/.exec(t);
            if (bm) {
                out.push({
                    num: bm[1],
                    active: bm[2] === "*",
                    label: bm[3].split("\t")[0]
                });
                continue;
            }
            const cm = /^BootCurrent:\s*([0-9A-Fa-f]{4})/.exec(t);
            if (cm) {
                current = cm[1];
                continue;
            }
            const nm = /^BootNext:\s*([0-9A-Fa-f]{4})/.exec(t);
            if (nm) {
                bootNext = nm[1];
                continue;
            }
            const om = /^BootOrder:\s*([0-9A-Fa-f,]+)/.exec(t);
            if (om)
                bootOrder = om[1];
        }
        out.sort((a, b) => parseInt(a.num, 16) - parseInt(b.num, 16));
        root.current = current;
        root.next = bootNext;
        root.entries = out;
        root.ready = true;
    }

    Component.onCompleted: root.refresh()
}