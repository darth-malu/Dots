pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Services.UPower

Singleton {
    id: root
    readonly property UPowerDevice battery: UPower.displayDevice

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

    property bool isLow: available && (batPercentage <= 18 / 100)
    property bool isCritical: available && (batPercentage <= 7 / 100)

    property int pctDisplay: Math.round(batPercentage * 100)

    function notify(summary, body, icon, urgency = "low") {
        const safeSummary = summary.replace(/'/g, "'\\''");
        const safeBody = body.replace(/'/g, "'\\''");
        const assetPath = `/home/malu/.config/quickshell/assets/battery/${icon}.png`;
        const cmd = `notify-send '${safeSummary}' '${safeBody}' -u ${urgency} -i ${assetPath} -a Shell && canberra-gtk-play -i bell`;
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    onChargeStateChanged: {
        const pct = root.pctDisplay;
        switch (chargeState) {
        case UPowerDeviceState.Charging:
            notify("🔌 Charging", `Battery at ${pct}%`, "plug");
            break;
        case UPowerDeviceState.Discharging:
            notify("🔋 Discharging", `Battery at ${pct}%`, "unplug");
            break;
        case UPowerDeviceState.FullyCharged:
            notify("✅ Fully Charged", `Battery is full at ${pct}%`, "full-battery");
            break;
        }
    }

    onBatPercentageChanged: {
        if (!isDischarging)
            return;
        const pct = root.pctDisplay;
        if (isCritical) {
            notify("🚨 Critical Battery!", `Battery at ${pct}% — plug in now!`, "warning-battery", "critical");
        } else if (isLow) {
            notify("⚠️ Low Battery", `Battery at ${pct}%`, "low-battery");
        }
    }
}
