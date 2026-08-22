pragma Singleton
import Quickshell
import QtQuick
import QtMultimedia
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice

    // charger events play a sound; while output is muted they fall back to a notification
    readonly property bool outputMuted: Pipewire.ready && root.sink?.audio?.muted === true
    readonly property PwNode sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: [root.sink]
    }

    SoundEffect {
        id: sfxPlug
        source: Qt.resolvedUrl("../customItems/game_ready.wav")
    }

    SoundEffect {
        id: sfxUnplug
        source: Qt.resolvedUrl("../customItems/game_ready.wav")
    }

    function plugEvent(summary, body, icon) {
        if (root.outputMuted)
            notify(summary, body, icon);
        else if (icon === "unplug")
            sfxUnplug.play();
        else
            sfxPlug.play();
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

    readonly property int lowThreshold: 20
    readonly property int criticalThreshold: 10
    readonly property bool isLow: available && !isPluggedIn && pctDisplay <= lowThreshold
    readonly property bool isCritical: available && !isPluggedIn && pctDisplay <= criticalThreshold

    property int pctDisplay: Math.round(batPercentage * 100)

    // rolling charge history for the popup graph (~1h window at 30s samples)
    property bool graphEnabled: false
    property var levelHistory: []

    Timer {
        interval: 30000
        running: root.available
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
        if (secs == null || isNaN(secs) || secs < 0)
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

    function notify(summary, body, icon, urgency = "normal", sound = false) {
        const safeSummary = summary.replace(/'/g, "'\\''");
        const safeBody = body.replace(/'/g, "'\\''");
        const assetPath = `/home/malu/.config/quickshell/assets/battery/${icon}.png`;
        const bell = sound ? " && canberra-gtk-play -i bell" : "";
        const cmd = `notify-send '${safeSummary}' '${safeBody}' -u ${urgency} -t 8000 -i ${assetPath} -a Shell${bell}`;
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
            break;
        case UPowerDeviceState.FullyCharged:
            plugEvent("Battery full", `${pct}% — you can unplug`, "full-battery");
            break;
        }
    }

    onBatPercentageChanged: {
        if (!root.available || root.isPluggedIn)
            return;
        const pct = root.pctDisplay;
        const left = timeLeftText();
        if (pct <= criticalThreshold && !warnedCritical) {
            warnedLow = true;
            warnedCritical = true;
            notify("Critical battery", `${pct}%${left ? ` · ~${left} left` : ""} — plug in now`, "warning-battery", "critical", true);
        } else if (pct <= lowThreshold && !warnedLow) {
            warnedLow = true;
            notify("Low battery", `${pct}%${left ? ` · ~${left} remaining` : ""}`, "low-battery", "normal", true);
        }
    }
}
