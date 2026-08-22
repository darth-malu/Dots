pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool active: persist.mode !== ""
    readonly property string mode: persist.mode

    // seconds left until the scheduled action fires
    property int remaining: 0
    property bool warned: false

    // survives config reloads (lost on full restart)
    PersistentProperties {
        id: persist
        property string mode: ""
        property date deadline: new Date(0)
        reloadableId: "powerTimer"
    }

    Component.onCompleted: {
        // resume a timer that was pending before a reload
        if (persist.mode !== "" && persist.deadline.getTime() > Date.now())
            tick();
        else
            clear();
    }

    Timer {
        interval: 1000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    function tick() {
        if (persist.mode === "")
            return;

        remaining = Math.max(0, Math.round((persist.deadline.getTime() - Date.now()) / 1000));

        if (remaining <= 0) {
            const m = persist.mode;
            clear();
            Quickshell.execDetached(["systemctl", m]);
            return;
        }

        if (remaining <= 60 && !warned) {
            warned = true;
            notify((persist.mode === "reboot" ? "Rebooting" : "Shutting down") + " in 1 minute", true);
        }
    }

    function scheduleReboot(seconds) {
        schedule("reboot", seconds);
    }

    function schedulePoweroff(seconds) {
        schedule("poweroff", seconds);
    }

    function schedule(mode, seconds) {
        persist.mode = mode;
        persist.deadline = new Date(Date.now() + seconds * 1000);
        warned = false;
        tick();
        notify((mode === "reboot" ? "Reboot" : "Shutdown") + " scheduled · " + formatTime(seconds));
    }

    function cancel() {
        if (persist.mode === "")
            return;
        const what = persist.mode === "reboot" ? "reboot" : "shutdown";
        clear();
        notify("Scheduled " + what + " cancelled");
    }

    function clear() {
        persist.mode = "";
        persist.deadline = new Date(0);
        remaining = 0;
        warned = false;
    }

    function formatTime(secs) {
        secs = Math.max(0, Math.floor(secs));
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s);
    }

    function notify(msg, urgent) {
        const args = ["notify-send", "-a", "Power Menu"];
        if (urgent === true)
            args.push("-u", "critical");
        args.push(msg);
        Quickshell.execDetached(args);
    }

    IpcHandler {
        target: "powerTimer"

        function rebootIn(minutes: int): void {
            root.scheduleReboot(minutes * 60);
        }

        function shutdownIn(minutes: int): void {
            root.schedulePoweroff(minutes * 60);
        }

        function cancel(): void {
            root.cancel();
        }
    }
}
