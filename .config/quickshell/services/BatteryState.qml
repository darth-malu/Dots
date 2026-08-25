pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import qs.services

Singleton {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice

    // charger events play a sound; while output is muted they fall back to a notification
    readonly property bool outputMuted: Pipewire.ready && root.sink?.audio?.muted === true
    readonly property PwNode sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: [root.sink]
    }

    readonly property string gameReadyWav: "/home/malu/.config/quickshell/customItems/game_ready.wav"

    function plugEvent(summary, body, icon) {
        if (root.outputMuted)
            notify(summary, body, icon);
        else if (icon === "unplug")
            Sfx.playPath(root.gameReadyWav);
        else
            Sfx.playPath(root.gameReadyWav);
    }

    readonly property var powerProfile: PowerProfiles.profile

    property bool perfMode: powerProfile === PowerProfile.Performance
    property bool saverMode: powerProfile === PowerProfile.PowerSaver
    property bool balMode: powerProfile === PowerProfile.Balanced

    property real batPercentage: battery.percentage
    property var chargeState: battery.state
    property bool available: battery.isLaptopBattery

    property bool isCharging: available && chargeState == UPowerDeviceState.Charging
    property bool isDischarging: chargeState == UPowerDeviceState.Discharging
    property bool isPluggedIn: isCharging || isPendingCharge
    property bool isPendingCharge: chargeState == UPowerDeviceState.PendingCharge
    property bool isPendingDischarge: chargeState == UPowerDeviceState.PendingDischarge
    property bool isFullyCharged: chargeState == UPowerDeviceState.FullyCharged

    readonly property int lowThreshold: 18
    readonly property int criticalThreshold: 5
    readonly property bool isLow: available && !isPluggedIn && pctDisplay <= lowThreshold
    readonly property bool isCritical: available && !isPluggedIn && pctDisplay <= criticalThreshold

    property int pctDisplay: Math.round(batPercentage * 100)

    // rolling charge history for the popup graph (~1h window at 30s samples)
    property bool graphEnabled: false
    property var levelHistory: []

    // ── adjustable poll rate (settings > performance) — history sampling, ms ──
    PersistentProperties {
        id: pollProps
        property int batteryInterval: 30000
        reloadableId: "batteryPollRate"
    }

    property alias batteryInterval: pollProps.batteryInterval

    Timer {
        interval: root.batteryInterval
        // sample only while the popup graph can display it — idle cost zero
        running: root.available && root.graphEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const h = root.levelHistory.slice(-119);
            h.push(root.batPercentage);
            root.levelHistory = h;
        }
    }

    // one-shot warning flags, re-armed whenever the charger is connected
    property bool warnedLow: false
    property bool warnedCritical: false
    property string lastChargeNotify: ""

    function fmtTime(secs) {
        // 0 means "still estimating" in UPower — report unknown, never "0m"
        if (secs == null || isNaN(secs) || secs <= 0)
            return null;
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }

    function timeLeftText() {
        return root.fmtTime(root.isCharging ? root.battery.timeToFull : root.battery.timeToEmpty);
    }

    function notify(summary, body, icon, urgency = "normal") {
        const safeSummary = summary.replace(/'/g, "'\\''");
        const safeBody = body.replace(/'/g, "'\\''");
        const assetPath = `/home/malu/.config/quickshell/assets/battery/${icon}.png`;
        const cmd = `notify-send '${safeSummary}' '${safeBody}' -u ${urgency} -t 8000 -i ${assetPath} -a Shell`;
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function resetWarnings() {
        root.warnedLow = false;
        root.warnedCritical = false;
    }

    onChargeStateChanged: {
        if (!root.available)
            return;

        // plugging in re-arms the low/critical warnings for the next discharge
        if (root.isPluggedIn || root.isFullyCharged)
            resetWarnings();

        // one notification per actual transition (UPower flaps pending states)
        const key = String(chargeState);
        if (key === root.lastChargeNotify)
            return;
        root.lastChargeNotify = key;

        const pct = root.pctDisplay;
        switch (chargeState) {
        case UPowerDeviceState.Charging:
            plugEvent("Charging", `Battery at ${pct}% · ${timeLeftText() ?? "estimating…"}`, "plug");
            break;
        case UPowerDeviceState.Discharging:
            plugEvent("Discharging", `Running on battery · ${pct}%`, "unplug");
            // unplugging while already low/critical must warn immediately
            evalWarnings();
            break;
        case UPowerDeviceState.FullyCharged:
            plugEvent("Battery full", `${pct}% — you can unplug`, "full-battery");
            break;
        }
    }

    function evalWarnings() {
        if (!root.available || root.isPluggedIn)
            return;
        const pct = root.pctDisplay;
        if (pct <= criticalThreshold && !warnedCritical) {
            warnedLow = true;
            warnedCritical = true;
            Sfx.play("mixkit-vintage-telephone-ringtone-1356.wav");
            notify("Battery Critical", `${pct}% — plug in charger now`, "warning-battery", "critical");
        } else if (pct <= lowThreshold && !warnedLow) {
            warnedLow = true;
            Sfx.play("mixkit-censorship-beep-1082.wav");
            notify("Battery Low", `${pct}% — plug in charger`, "low-battery");
        }
    }

    onBatPercentageChanged: evalWarnings()

    // covers boot/already-low-on-unplug cases where the percentage never changes
    Component.onCompleted: Qt.callLater(evalWarnings)
}
