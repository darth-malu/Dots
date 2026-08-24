pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lightweight speed test — measures TCP RTT, download and upload against
// Cloudflare's speed endpoints with curl (no extra packages needed).
Singleton {
    id: root

    property bool running: false
    // "" | "ping" | "down" | "up"
    property string phase: ""
    property real pingMs: -1
    property real downMbps: -1
    property real upMbps: -1
    property string error: ""

    readonly property bool finished: !running && pingMs >= 0 && downMbps >= 0 && error === ""

    function start() {
        if (root.running)
            return;
        pingMs = -1;
        downMbps = -1;
        upMbps = -1;
        error = "";
        phase = "ping";
        running = true;
        proc.running = true;
    }

    function cancel() {
        if (!root.running)
            return;
        proc.running = false;
        _reset("cancelled");
    }

    function _reset(msg) {
        running = false;
        phase = "";
        if (msg)
            error = msg;
    }

    function _mbps(bps) {
        return Math.round(bps * 8 / 100000) / 10;
    }

    Process {
        id: proc

        command: ["sh", "-c",
            'tmp=$(mktemp); head -c 8000000 /dev/urandom > "$tmp"; '
            + 'echo "phase ping"; '
            + 'for i in 1 2 3; do curl -4 -o /dev/null -s --max-time 6 -w \'%{time_connect}\\n\' "https://speed.cloudflare.com/__down?bytes=0"; done | sort -n | head -1 | awk \'{printf "ping %.1f\\n", $1*1000}\'; '
            + 'echo "phase down"; '
            + 'curl -4 -o /dev/null -s --max-time 20 -w "down %{speed_download}\\n" "https://speed.cloudflare.com/__down?bytes=50000000"; '
            + 'echo "phase up"; '
            + 'curl -4 -o /dev/null -s --max-time 25 -X POST --data-binary @"$tmp" -H "Content-Type: application/octet-stream" -w "up %{speed_upload}\\n" https://speed.cloudflare.com/__up; '
            + 'rm -f "$tmp"; echo done']
        running: false

        stdout: SplitParser {
            onRead: data => {
                const t = data.trim();
                if (t.startsWith("phase "))
                    root.phase = t.substring(6);
                else if (t.startsWith("ping "))
                    root.pingMs = parseFloat(t.split(" ")[1]) || -1;
                else if (t.startsWith("down "))
                    root.downMbps = root._mbps(parseFloat(t.split(" ")[1]));
                else if (t.startsWith("up "))
                    root.upMbps = root._mbps(parseFloat(t.split(" ")[1]));
                else if (t === "done") {}
                else if (t.length > 0)
                    root.error = t;
            }
        }

        onExited: {
            if (pingMs < 0 || downMbps < 0)
                _reset(pingMs < 0 ? "no response from server" : "test incomplete");
            else {
                if (upMbps < 0)
                    upMbps = 0;
                running = false;
                phase = "";
            }
        }
    }
}
