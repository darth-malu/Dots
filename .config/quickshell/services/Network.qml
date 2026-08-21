pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

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

    // catppuccin mocha: surface2 / red / peach→yellow→green by signal
    readonly property color wifiColor: {
        if (!Networking.wifiEnabled)
            return "#6c7086";
        if (!root.activeNetwork)
            return "#f38ba8";

        const s = root.activeNetwork.signalStrength;
        return s < 0.34 ? "#fab387" : s < 0.67 ? "#f9e2af" : "#a6e3a1";
    }

    // catppuccin mocha: overlay0 / teal
    readonly property color ethColor: !root.ethernet?.hasLink ? "#6c7086" : "#94e2d5"
}
