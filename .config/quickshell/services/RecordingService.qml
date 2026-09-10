pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Screen recording (wf-recorder) — bar button toggles it, mirroring the
// CaffeineService architecture. Picks its own timestamped path under
// ~/Videos/Recordings; stopping ships wf-recorder a SIGINT (graceful mp4
// finalize) and announces the saved file.
Singleton {
    id: root

    property bool recording: false

    readonly property string dir: Quickshell.env("HOME") + "/Videos/Recordings"
    property string filePath: ""

    function _stamp(): string {
        const d = new Date();
        const p = n => (n < 10 ? "0" : "") + n;
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "_" + p(d.getHours()) + "-" + p(d.getMinutes()) + "-" + p(d.getSeconds());
    }

    function toggle(): void {
        if (root.recording)
            root.stop();
        else
            root.start();
    }

    function start(): void {
        if (root.recording)
            return;
        root.filePath = root.dir + "/screen_" + root._stamp() + ".mp4";
        recProc.command = ["sh", "-c", "mkdir -p \"$1\" && exec wf-recorder -a -f \"$2\"", "sh", root.dir, root.filePath];
        recProc.running = true;
        root.recording = true;
        Sfx.play("mixkit-positive-interface-beep-221.wav");
        Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "media-record", "Recording", "Screen recording started"]);
    }

    function stop(): void {
        if (!root.recording)
            return;
        // SIGINT so wf-recorder finalizes the mp4 in place
        Quickshell.execDetached(["pkill", "-INT", "-f", "wf-recorder"]);
        Sfx.play("mixkit-censorship-beep-1082.wav");
    }

    Process {
        id: recProc
        running: false
        onExited: code => {
            if (!root.recording)
                return;
            root.recording = false;
            if (code === 0 && root.filePath.length > 0) {
                Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "video-x-generic", "Recording saved", root.filePath]);
            } else {
                Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "dialog-error", "Recording failed", "wf-recorder exited (" + code + ")"]);
            }
        }
    }

    IpcHandler {
        target: "recorder"

        function isRecording(): bool {
            return root.recording;
        }

        function toggle(): void {
            root.toggle();
        }

        function start(): void {
            root.start();
        }

        function stop(): void {
            root.stop();
        }
    }
}
