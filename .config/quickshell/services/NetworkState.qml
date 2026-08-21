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

    readonly property WifiDevice adapter: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property WifiNetwork activeNetwork: root.adapter ? root.adapter.networks.values.find(network => network.connected) : null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property WiredDevice ethernet: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wifiConnected: root.adapter?.connected ?? false

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

    // dracula: surface2 / red / peach→yellow→green by signal
    readonly property color wifiColor: {
        if (!Networking.wifiEnabled)
            return "#6272a4";
        if (!root.activeNetwork)
            return "#ff5555";

        const s = root.activeNetwork.signalStrength;
        return s < 0.34 ? "#ffb86c" : s < 0.67 ? "#f1fa8c" : "#50fa7b";
    }

    // dracula: overlay0 / teal
    readonly property color ethColor: !root.ethernet?.hasLink ? "#6272a4" : "#8be9fd"
}
