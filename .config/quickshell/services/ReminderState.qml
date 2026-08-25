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
    // plain property refreshed by the due-timer — a binding here would be
    // computed once and go stale past midnight (no reactive deps)
    property string todayKey: _fmtToday()

    function _fmtToday() {
        const d = new Date();
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    function _fmtOffset(days) {
        const d = new Date();
        d.setDate(d.getDate() + days);
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    readonly property string tomorrowKey: _fmtOffset(1)

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
    // pending-count map keyed by "YYYY-MM-DD" — rebuilt only when the
    // list changes instead of scanning per calendar cell (42 cells × N)
    readonly property var _countsByDate: {
        const m = ({});
        for (const r of reminders)
            if (!r.done)
                m[r.date] = (m[r.date] ?? 0) + 1;
        return m;
    }

    function countForDate(year, month, day) {
        const key = year + "-" + String(month + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0");
        return _countsByDate[key] ?? 0;
    }

    // ── mutations ──
    function add(text, dateKey, timeStr) {
        const t = (text || "").trim();
        const dOk = /^\d{4}-\d{2}-\d{2}$/.test(dateKey || "");
        const tClean = (timeStr || "").trim();
        const tOk = tClean.length === 0 || /^\d{2}:\d{2}$/.test(tClean);
        if (t.length === 0 || !dOk || !tOk)
            return -1;
        // Date.now() alone can collide for rapid successive adds
        let id = Date.now();
        while (reminders.some(r => r.id === id))
            id++;
        reminders = [...reminders, {
            id: id,
            text: t,
            date: dateKey,
            time: tClean,
            done: false,
            notified: false
        }];
        notify("Reminder set · " + dateKey + (tClean ? " " + tClean : ""), t);
        return 0;
    }

    function remove(id) {
        reminders = reminders.filter(r => r.id !== id);
    }

    // edit an existing reminder in place — text/date/time replaced, and a
    // fired flag is cleared so an edited time can ring again
    function update(id, text, dateKey, timeStr) {
        const t = (text || "").trim();
        const dOk = /^\d{4}-\d{2}-\d{2}$/.test(dateKey || "");
        const tClean = (timeStr || "").trim();
        const tOk = tClean.length === 0 || /^\d{2}:\d{2}$/.test(tClean);
        if (t.length === 0 || !dOk || !tOk)
            return false;
        if (!reminders.some(r => r.id === id))
            return false;
        reminders = reminders.map(r => r.id === id ? Object.assign({}, r, {
                    text: t,
                    date: dateKey,
                    time: tClean,
                    notified: false
                }) : r);
        return true;
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
        onTriggered: {
            const t = root._fmtToday();
            if (t !== root.todayKey)
                root.todayKey = t; // midnight rollover keeps every query honest
            root.checkDue();
        }
    }

    function checkDue() {
        const nowKey = todayKey;
        const nowTime = Qt.formatDateTime(new Date(), "HH:mm");
        let changed = false;
        const next = reminders.map(r => {
            if (r.notified || r.done)
                return r;
            // timed reminders fire once their minute arrives (incl. late
            // boots); all-day tasks deliberately never alarm
            if (r.time && r.date === nowKey && r.time <= nowTime) {
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

        function edit(id: string, text: string, date: string, time: string): string {
            return root.update(Number(id), text, date, time) ? "ok" : "invalid";
        }

        function done(id: string): void {
            root.toggleDone(Number(id));
        }
    }
}
