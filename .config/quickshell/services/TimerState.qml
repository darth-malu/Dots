pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Noctalia-style headless countdown timer:
// · one shared countdown, driven by an absolute deadline (survives reloads)
// · any surface (timer panel, bar widget, IPC) drives the same state
// · fires a chime + critical notification when the countdown reaches zero
Singleton {
    id: root

    // 0 idle · 1 running · 2 paused · 3 done
    property int phase: 0
    // length of the current run — keeps the progress ring honest across +N adds
    property int durationSec: 0
    property int remainingSec: 0

    readonly property bool running: phase === 1
    readonly property bool active: phase === 1 || phase === 2

    // ── persistence (survives config reloads, lost on full restart) ──
    PersistentProperties {
        id: persist

        property int phase: 0
        property int durationSec: 0
        property date deadline: new Date(0)
        reloadableId: "countdownTimer"
    }

    Component.onCompleted: {
        if (persist.phase === 1 && persist.deadline.getTime() > Date.now()) {
            root.durationSec = persist.durationSec;
            root.phase = 1;
            tick();
        } else if (persist.phase === 2) {
            root.durationSec = persist.durationSec;
            remainingSec = Math.max(0, Math.round((persist.deadline.getTime() - Date.now()) / 1000));
            root.phase = 2;
        } else {
            clear();
        }
    }

    function _syncPersist() {
        persist.phase = phase;
        persist.durationSec = durationSec;
        persist.deadline = running ? new Date(Date.now() + remainingSec * 1000) : persist.deadline;
    }

    Timer {
        interval: 1000
        running: root.running
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    function tick() {
        if (!running)
            return;
        remainingSec = Math.max(0, Math.round((persist.deadline.getTime() - Date.now()) / 1000));
        if (remainingSec <= 0)
            finish();
    }

    function finish() {
        phase = 3;
        _syncPersist();
        Sfx.playPath("/home/malu/.config/quickshell/wav/mixkit-positive-interface-beep-221.wav");
        Quickshell.execDetached(["notify-send", "-u", "critical",
            "-a", "Timer", "-i", "office-clock",
            "\uf017  Time's up", formatTime(durationSec) + " elapsed"]);
    }

    // ── controls ──
    // arm a duration without starting — stays idle (bar shows nothing).
    // while a countdown is live this RESIZES it instead: remaining jumps to
    // the given value (up or down), duration grows if needed so the ring
    // never exceeds full
    function setDuration(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        if (active) {
            remainingSec = s;
            if (durationSec < s)
                durationSec = s;
            if (running) {
                persist.deadline = new Date(Date.now() + s * 1000);
                tick();
            } else {
                _syncPersist();
            }
            return;
        }
        durationSec = s;
        remainingSec = s;
        phase = 0;
        _syncPersist();
    }

    function start(seconds) {
        const dur = Math.max(1, Math.floor(seconds ?? durationSec));
        durationSec = dur;
        remainingSec = dur;
        _begin();
    }

    function resume() {
        if (phase === 2 && remainingSec > 0)
            _begin();
    }

    function _begin() {
        persist.deadline = new Date(Date.now() + remainingSec * 1000);
        phase = 1;
        tick();
    }

    function toggle() {
        if (running)
            pause();
        else if (phase === 2)
            resume();
        else if (remainingSec > 0)
            _begin();
    }

    function pause() {
        if (!running)
            return;
        tick();
        // tick() may have crossed zero and finished() already — don't clobber
        // phase 3 back to paused-at-zero (that state could never resume)
        if (!running)
            return;
        phase = 2;
        _syncPersist();
    }

    // stop + drop the countdown to zero. every phase lands here:
    // running/paused are discarded, done loses its flag, armed durations
    // keep durationSec so the spinners can pre-fill the next run.
    function reset() {
        if (phase === 0 && remainingSec === 0)
            return; // already at zero — don't write persistence for a no-op
        phase = 0;
        remainingSec = 0;
        persist.phase = 0;
        persist.deadline = new Date(0); // stale deadline must never resurrect a run
    }

    // forget everything including the stored duration
    function clear() {
        phase = 0;
        durationSec = 0;
        remainingSec = 0;
        persist.phase = 0;
        persist.durationSec = 0;
        persist.deadline = new Date(0);
    }

    // restart the same duration from full
    function restart() {
        if (durationSec <= 0)
            return;
        remainingSec = durationSec;
        _begin();
    }

    // +n minutes while running/paused (noctalia desktop-widget style),
    // extends the ring too; negatives shrink and floor at zero
    function addMinutes(mins) {
        const s = Math.round(mins * 60);
        if (phase === 0 || phase === 3) {
            setDuration(Math.max(0, durationSec + s));
            return;
        }
        if (remainingSec + s <= 0) {
            // shrinking past zero ends the run cleanly
            durationSec = Math.max(0, durationSec + s);
            remainingSec = 0;
            finish();
            return;
        }
        durationSec += s;
        remainingSec += s;
        if (running) {
            persist.deadline = new Date(persist.deadline.getTime() + s * 1000);
            tick();
        } else {
            _syncPersist();
        }
    }

    function formatTime(secs) {
        secs = Math.max(0, Math.floor(secs));
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s);
    }

    // ── IPC ──
    function statusJson(): string {
        return JSON.stringify({
                "phase": phase,
                "remaining": remainingSec,
                "duration": durationSec
            });
    }

    IpcHandler {
        target: "timer"

        function start(seconds: int): string {
            root.start(seconds);
            return "ok";
        }

        function toggle(): void {
            root.toggle();
        }

        function reset(): void {
            root.reset();
        }

        function add(minutes: int): void {
            root.addMinutes(minutes);
        }

        function status(): string {
            return root.statusJson();
        }
    }
}
