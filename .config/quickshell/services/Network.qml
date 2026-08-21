pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

    // property bool connectionStatus: Networking. n
    readonly property WifiDevice adapter: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
    readonly property WiredDevice ethernet: Networking.devices.values.find(d => d.type === DeviceType.Wired)
    readonly property bool wifiConnected: adapter.connected
    readonly property WifiNetwork activeNetwork: adapter.networks.values.find(network => network.connected)

    readonly property string wifiIcon: {
        if (root.adapter) {
            if (!Networking.wifiEnabled)
                return "root:/icons/wifi-slash.svg";
            if (!root.adapter.connected)
                return "root:/icons/wifi-x.svg";
            return `root:/icons/wifi-${Math.round(root.activeNetwork.signalStrength * 3)}.svg`;
        }

        return "root:/icons/wifi-x.svg";
    }

    readonly property string ethIcon: {
        if (root.ethernet) {
            if (!root.ethernet.network)
                return "root:/icons/ethernet-x.svg";
            else if (!root.ethernet.network.connected)
                return "root:/icons/ethernet-slash.svg";
            else
                return "root:/icons/ethernet.svg";
        }

        return "root:/icons/ethernet-x.svg";
    }
}
