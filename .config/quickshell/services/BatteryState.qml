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

    property real batPercentage: battery.percentage // Energy/EnergyCapacity

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

    function notify(msg, icon, urgency = "low") {
        const assetPath = `/home/malu/.config/quickshell/assets/battery/${icon}.png`;
        const cmd = `notify-send '${msg}' -u ${urgency} -i ${assetPath} -a Shell && canberra-gtk-play -i bell`;
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    onChargeStateChanged: {
        switch (chargeState) {
        case UPowerDeviceState.Charging:
            Quickshell.execDetached(["sh", "-c", "notify-send 'Charger Connected' -u low -i /home/malu/.config/quickshell/assets/battery/plug.png -a Shell && canberra-gtk-play -i bell"]);
            break;
        case UPowerDeviceState.Discharging:
            Quickshell.execDetached(["sh", "-c", "notify-send 'Charger Disconnected' -u low -i /home/malu/.config/quickshell/assets/battery/unplug.png -a Shell && canberra-gtk-play -i bell"]);
            break;
        case UPowerDeviceState.FullyCharged:
            Quickshell.execDetached(["sh", "-c", "notify-send 'Fully Charged' -u low -i /home/malu/.config/quickshell/assets/battery/full-battery.png -a Shell && canberra-gtk-play -i bell"]);
            break;
        }
    }

    onBatPercentageChanged: {
        if (!isDischarging)
            return;
        if (isCritical) {
            notify("Critical battery!", "warning-battery", "critical");
        } else if (isLow) {
            notify("Low battery", "low-battery");
        }
    }
}
