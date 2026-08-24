pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

    property bool netspeedVisible: false
    property bool netPopupVisible: false
    property bool btPopupVisible: false
    property bool wifiPopupVisible: false
    property bool notifCenterVisible: false

    // ── adjustable poll rate (settings > performance) — netspeed refresh, ms ──
    PersistentProperties {
        id: pollProps
        property int netInterval: 1000
        reloadableId: "netPollRate"
    }

    property alias netInterval: pollProps.netInterval

    readonly property WifiDevice adapter: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property WifiNetwork activeNetwork: root.adapter ? root.adapter.networks.values.find(network => network.connected) : null
    readonly property bool wifiEnabled: Networking.wifiEnabled

    // master "internet" switch: any live radio/link counts as on
    readonly property bool internetEnabled: Networking.wifiEnabled || (root.ethernet?.connected ?? false)

    function setInternetEnabled(on) {
        if (on) {
            Networking.wifiEnabled = true;
            return;
        }
        Networking.wifiEnabled = false;
        if (root.ethernet?.connected)
            root.ethernet.disconnect();
    }

    readonly property WiredDevice ethernet: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wifiConnected: root.adapter?.connected ?? false

    // ── radio / link toggles (settings network page) ──
    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }

    // ethernet wins policy: when the cable link comes up, drop Wi-Fi once
    // (rising edge only — manual reconnection afterwards is respected)
    property bool ethLinkWasUp: false

    onEthernetChanged: Qt.callLater(_syncEthLink)

    function _syncEthLink() {
        const t = root.ethernet;
        if (!t)
            return;
        t.hasLinkChanged.connect(() => root._onEthLink(t));
        root._onEthLink(t);
    }

    function _onEthLink(dev) {
        const up = dev.hasLink;
        if (up && !root.ethLinkWasUp && root.wifiConnected && Networking.wifiEnabled) {
            Quickshell.execDetached(["notify-send", "-a", "Shell", "Ethernet connected", "Wi-Fi disconnected"]);
            root.adapter?.disconnect();
        }
        root.ethLinkWasUp = up;
    }

    Component.onCompleted: Qt.callLater(_syncEthLink)

    function setEthernetEnabled(on) {
        if (!root.ethernet)
            return;
        if (!on)
            root.ethernet.disconnect();
        else
            Quickshell.execDetached(["sh", "-c", `nmcli device connect '${root.ethernet.name}' 2>/dev/null`]);
    }

    readonly property string wifiIcon: {
        if (root.adapter) {
            if (!Networking.wifiEnabled)
                return "root:/icons/wifi-slash.svg";
            if (!root.wifiConnected)
                return "root:/icons/wifi-x.svg";
            return `root:/icons/wifi-${Math.round(root.activeNetwork.signalStrength * 3)}.svg`;
        }

        return "root:/icons/wifi-x.svg";
    }

    readonly property string ethIcon: {
        if (root.ethernet) {
            if (!root.ethernet.network || !root.ethernet.network.connected)
                return "root:/icons/ethernet-x.svg";
            else
                return "root:/icons/ethernet.svg";
        }

        return "root:/icons/ethernet-x.svg";
    }

    // gray = disabled/no adapter · purple = idle · peach→yellow→cyan by signal
    readonly property color wifiColor: {
        if (!root.adapter || !Networking.wifiEnabled)
            return "#6272a4";
        if (!root.activeNetwork)
            return "#bd93f9";

        const s = root.activeNetwork.signalStrength;
        return s < 0.34 ? "#ffb86c" : s < 0.67 ? "#f1fa8c" : "#8be9fd";
    }

    // dracula: overlay0 / teal
    readonly property color ethColor: !root.ethernet?.hasLink ? "#6272a4" : "#8be9fd"

    // popup traffic graphs — each toggle makes its graph section visible AND starts history sampling
    property bool wifiGraphEnabled: false
    property bool ethGraphsEnabled: false

    // themed "connection established" popup — replaces nm-applet's stock notification
    readonly property string iconsDir: "/home/malu/.config/quickshell/icons"
    property bool wasWifiConnected: false

    function currentWifiIconPath() {
        if (!root.adapter || !Networking.wifiEnabled)
            return `${root.iconsDir}/wifi-slash.svg`;
        if (!root.wifiConnected)
            return `${root.iconsDir}/wifi-x.svg`;
        return `${root.iconsDir}/wifi-${Math.round((root.activeNetwork?.signalStrength ?? 0) * 3)}.svg`;
    }

    onWifiConnectedChanged: {
        // suppressed while the wifi popup is open — the connection is visible there
        if (root.wifiConnected && !root.wasWifiConnected && !root.wifiPopupVisible) {
            const ssid = String(root.activeNetwork?.name ?? "").replace(/'/g, "'\\''");
            const sig = Math.round((root.activeNetwork?.signalStrength ?? 0) * 100);
            Quickshell.execDetached(["sh", "-c",
                `notify-send '${ssid}' 'signal · ${sig}%' -i ${root.currentWifiIconPath()} -a Shell -t 4000`]);
        }
        root.wasWifiConnected = root.wifiConnected;
    }
}
