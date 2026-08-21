pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import QtQuick

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    readonly property bool enabled: adapter?.enabled ?? false

    readonly property var btDevices: adapter.devices.values

    readonly property bool connected: adapter?.connected

    readonly property string btIcon: !enabled ? "root:/icons/bluetooth-slash.svg" : connected ? "root:/icons/bluetooth-connected.svg" : "root:/icons/bluetooth.svg"

    readonly property string btDev: {
        const dev = devices.find(device => device.connected);
        return dev ? dev.name : "";
    }

    readonly property real btBat: {
        const dev = devices.find(device => device.batteryAvailable);
        return dev ? dev.battery * 100 : 0;
    }

    readonly property bool btTrust: devices.some(device => device.trusted)

    readonly property color btColor: !enabled ? "grey" : (connected ? "blue" : "pink")
}
