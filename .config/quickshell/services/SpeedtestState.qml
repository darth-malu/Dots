pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Lightweight speed test against Cloudflare's speed endpoints with curl.
//
// v3: each phase (ping/down/up) is its own short-lived curl loop, every
// completed probe/chunk reports a line so `progress` fills continuously,
// and a watchdog timer guarantees a stalled test can never run forever.
// The last 10 results (with the active network name) persist to
// speedtest-history.json next to reminders.json.
Singleton {
    id: root

    property bool running: false
    // "" | "ping" | "down" | "up"
    property string phase: ""
    // 0..1 within the current phase; 1 when idle & complete
    property real progress: 0
    property real pingMs: -1
    property real downMbps: -1
    property real upMbps: -1
    property string error: ""

    // test metadata — populated during the run
    property string server: ""
    property real totalMB: 0
    property real testDuration: 0

    // last 10 runs, newest first: {ts, ping, down, up, net, server, mb, secs}
    property var history: []

    readonly property bool finished: !running && pingMs >= 0 && downMbps >= 0 && error === ""

    function start() {
        if (root.running)
            return;
        _phaseDone = false;
        running = true;
        pingMs = -1;
        downMbps = -1;
        upMbps = -1;
        error = "";
        server = "";
        totalMB = 0;
        testDuration = 0;
        _startMs = Date.now();
        root._pingProbes = [];
        root._downChunks = [];
        root._upChunks = [];
        root._startPhase("ping");
    }

    function cancel() {
        if (!root.running)
            return;
        watchdog.stop();
        proc.running = false;
        root._reset("cancelled");
    }

    function clearHistory() {
        root.history = [];
    }

    function _reset(msg) {
        running = false;
        phase = "";
        progress = 0;
        _phaseDone = false;
        if (msg)
            error = msg;
    }

    // set when the current phase's trailing "done" marker is parsed; the
    // actual phase hand-off waits for onExited so the old process is fully
    // dead before the next one takes over the shared Process
    property bool _phaseDone: false
    property real _startMs: 0

    function _startPhase(name) {
        phase = name;
        progress = 0;
        watchdog.interval = name === "ping" ? 25000 : name === "down" ? 100000 : 80000;
        watchdog.restart();
        proc.command = ["/bin/sh", "-c", name === "ping" ? _script_ping() : name === "down" ? _script_down() : _script_up()];
        proc.running = true;
    }

    // scratch buffers filled by the stdout parser
    property var _pingProbes: []
    property var _downChunks: []
    property var _upChunks: []

    // ── phase scripts — one status line per probe/chunk keeps progress live ──
    function _script_ping() {
        return 'for i in 1 2 3; do '
            + 'curl -4 -o /dev/null -s --max-time 6 '
            + '-w "probe %{time_connect} %{remote_ip}\\n" "https://speed.cloudflare.com/__down?bytes=0"; '
            + 'done; echo done';
    }

    function _script_down() {
        return 'for i in 1 2 3 4 5; do '
            + 'curl -4 -s --max-time 15 -o /dev/null '
            + '-w "chunk %{size_download} %{time_total}\\n" '
            + '"https://speed.cloudflare.com/__down?bytes=10000000"; '
            + 'done; echo done';
    }

    function _script_up() {
        return 'tmp=$(mktemp); trap \'rm -f "$tmp"\' EXIT; '
            + 'head -c 3000000 /dev/urandom > "$tmp"; '
            + 'for i in 1 2 3; do '
            + 'curl -4 -s --max-time 20 -X POST --data-binary @"$tmp" '
            + '-H "Content-Type: application/octet-stream" '
            + '-w "chunk %{size_upload} %{time_total}\\n" '
            + 'https://speed.cloudflare.com/__up; '
            + 'done; echo done';
    }

    function _mbps(bytes, seconds) {
        if (seconds <= 0 || bytes <= 0)
            return -1;
        return Math.round(bytes * 8 / seconds / 100000) / 10;
    }

    // which network the test ran on — wifi ssid or ethernet
    function _netName() {
        if (NetworkState.ethernet?.hasLink)
            return "Ethernet";
        if (NetworkState.wifiConnected && NetworkState.activeNetwork?.name)
            return NetworkState.activeNetwork.name;
        return "";
    }

    function _finish() {
        watchdog.stop();
        // final validation only — phase chaining lives in onExited
        if (pingMs < 0 || downMbps < 0) {
            _reset(pingMs < 0 ? "no response from server" : "test incomplete");
            return;
        }
        if (upMbps < 0)
            upMbps = 0;
        running = false;
        phase = "";
        progress = 1;
        testDuration = (Date.now() - _startMs) / 1000;

        const entry = {
            ts: Math.floor(Date.now() / 1000),
            ping: pingMs,
            down: downMbps,
            up: upMbps,
            net: _netName(),
            server: server,
            mb: Math.round(totalMB * 10) / 10,
            secs: Math.round(testDuration)
        };
        history = [entry].concat(history).slice(0, 10);
    }

    // ── persistent store (same pattern as reminders.json) ──
    FileView {
        id: histStore

        path: Quickshell.env("HOME") + "/.config/quickshell/speedtest-history.json"
        watchChanges: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.history = prefs.entries ?? []

        JsonAdapter {
            id: prefs

            property var entries: []
        }
    }

    onHistoryChanged: prefs.entries = history

    // kill switch — no phase may outlive its budget
    Timer {
        id: watchdog

        interval: 60000
        repeat: false
        onTriggered: {
            proc.running = false;
            root._reset("stalled — timed out");
        }
    }

    Process {
        id: proc

        running: false

        stdout: SplitParser {
            onRead: data => {
                const t = data.trim();
                if (t.length === 0)
                    return;
                if (t === "done") {
                    root._phaseDone = true;
                    return;
                }
                const parts = t.split(" ");
                if (parts[0] === "probe") {
                    const ms = parseFloat(parts[1]) * 1000;
                    if (ms > 0 && (root.pingMs < 0 || ms < root.pingMs))
                        root.pingMs = ms;
                    // second field is the remote IP — capture from the first successful probe
                    if (parts.length > 2 && parts[2].length > 0 && root.server.length === 0)
                        root.server = parts[2];
                    root._pingProbes.push(1);
                    root.progress = root._pingProbes.length / 3;
                } else if (parts[0] === "chunk") {
                    const bytes = parseFloat(parts[1]);
                    const secs = parseFloat(parts[2]);
                    if (!(bytes > 0) || !(secs > 0)) {
                        root.error = "transfer failed";
                        return;
                    }
                    root.totalMB += bytes / 1000000;
                    if (root.phase === "down") {
                        root._downChunks.push([bytes, secs]);
                        root.downMbps = root._mbps(root._downChunks.reduce((a, c) => a + c[0], 0), root._downChunks.reduce((a, c) => a + c[1], 0));
                        root.progress = root._downChunks.length / 5;
                    } else {
                        root._upChunks.push([bytes, secs]);
                        root.upMbps = root._mbps(root._upChunks.reduce((a, c) => a + c[0], 0), root._upChunks.reduce((a, c) => a + c[1], 0));
                        root.progress = root._upChunks.length / 3;
                    }
                } else if (t.startsWith("Warning") || t.startsWith("  %")) {
                    // curl noise — ignore
                } else {
                    root.error = t;
                }
            }
        }

        onExited: {
            // cancelled / killed by the watchdog already tore the run down
            if (!root.running)
                return;
            if (!root._phaseDone) {
                // exited without completing its loop — killed or died early
                root._reset("no response from server");
                return;
            }
            root._phaseDone = false;
            // chain ping → down → up → commit
            if (root.phase === "ping")
                root._startPhase("down");
            else if (root.phase === "down")
                root._startPhase("up");
            else
                root._finish();
        }
    }
    // headless control / inspection of the test flow
    IpcHandler {
        target: "speedtest"

        function start(): string {
            root.start();
            return "started";
        }

        function cancel(): void {
            root.cancel();
        }

        function status(): string {
            return JSON.stringify({
                    "running": root.running,
                    "phase": root.phase,
                    "progress": Math.round(root.progress * 100),
                    "ping": root.pingMs,
                    "down": root.downMbps,
                    "up": root.upMbps,
                    "error": root.error,
                    "server": root.server,
                    "mb": Math.round(root.totalMB * 10) / 10,
                    "secs": Math.round(root.testDuration)
                });
        }
    }
}
