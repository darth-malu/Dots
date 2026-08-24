pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lightweight reminder system (omarchy-inspired):
// · reminders live in reminders.json and survive reloads/restarts
// · a timer fires a critical notification + chime when due
// · managed from the calendar popup (clock) or the `reminders` IPC target
Singleton {
    id: root

    // [{id, text, date: "YYYY-MM-DD", time: "HH:mm", done, notified}]
    // deliberately NOT bound to prefs — a binding plus the write-back in
    // onRemindersChanged formed a circular dependency (binding-loop warn)
    property var reminders: []

    // ── persistent store ──
    FileView {
        id: prefStore

        path: Quickshell.env("HOME") + "/.config/quickshell/reminders.json"
        watchChanges: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.reminders = prefs.reminders ?? []

        JsonAdapter {
            id: prefs

            property var reminders: []
        }
    }

    onRemindersChanged: prefs.reminders = reminders

    // ── queries ──
    readonly property string todayKey: {
        const d = new Date();
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    // upcoming = not done/not fired-yet-visible, today-or-later, soonest first
    readonly property var upcoming: {
        const nowTime = Qt.formatDateTime(new Date(), "HH:mm");
        return reminders
            .filter(r => !r.done)
            .filter(r => {
                if (r.date > todayKey)
                    return true;
                if (r.date < todayKey)
                    return false;
                return !r.time || r.time >= nowTime;
            })
            .sort((a, b) => (a.date + (a.time || "99:99")).localeCompare(b.date + (b.time || "99:99")));
    }

    // everything still pending (incl. past-due) — what the popup displays
    readonly property var pending: reminders
        .filter(r => !r.done)
        .sort((a, b) => (a.date + (a.time || "99:99")).localeCompare(b.date + (b.time || "99:99")));

    // reminder dot count for a calendar day cell
    function countForDate(year, month, day) {
        const key = year + "-" + String(month + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0");
        let n = 0;
        for (const r of reminders)
            if (!r.done && r.date === key)
                n++;
        return n;
    }

    // ── mutations ──
    function add(text, dateKey, timeStr) {
        const t = (text || "").trim();
        if (t.length === 0 || !dateKey)
            return -1;
        reminders = [...reminders, {
            id: Date.now(),
            text: t,
            date: dateKey,
            time: timeStr || "",
            done: false,
            notified: false
        }];
        notify("Reminder set · " + dateKey + (timeStr ? " " + timeStr : ""), t);
        return 0;
    }

    function remove(id) {
        reminders = reminders.filter(r => r.id !== id);
    }

    function toggleDone(id) {
        reminders = reminders.map(r => r.id === id ? Object.assign({}, r, {
                    done: !r.done
                }) : r);
    }

    // ── firing ──
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkDue()
    }

    function checkDue() {
        const nowKey = todayKey;
        const nowTime = Qt.formatDateTime(new Date(), "HH:mm");
        let changed = false;
        const next = reminders.map(r => {
            if (r.notified || r.done)
                return r;
            if (r.date === nowKey && (!r.time || r.time <= nowTime)) {
                changed = true;
                fire(r);
                return Object.assign({}, r, {
                    notified: true
                });
            }
            return r;
        });
        if (changed)
            reminders = next;
    }

    function fire(r) {
        Sfx.playPath("/home/malu/.config/quickshell/wav/mixkit-vintage-telephone-ringtone-1356.wav");
        Quickshell.execDetached(["notify-send", "-u", "critical",
            "-a", "Reminders", "-i", "appointment-soon",
            "\uf0f3  Reminder" + (r.time ? " · " + r.time : ""),
            r.text]);
    }

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Reminders", title, body]);
    }

    // ── IPC ──
    IpcHandler {
        target: "reminders"

        function add(text: string, date: string, time: string): string {
            return root.add(text, date, time) === 0 ? "ok" : "invalid";
        }

        function list(): string {
            return JSON.stringify(root.pending);
        }

        // ids are epoch-millis — passed as strings to dodge the 32-bit IPC int
        function remove(id: string): void {
            root.remove(Number(id));
        }

        function done(id: string): void {
            root.toggleDone(Number(id));
        }
    }
}
