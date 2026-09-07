pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import QtQuick

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter?.devices.values ?? []

    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool connected: devices.some(device => device.connected)

    readonly property string btIcon:
        !enabled ? "root:/icons/bluetooth-slash.svg"
        : connected ? "root:/icons/bluetooth-connected.svg"
        : "root:/icons/bluetooth.svg"

    // dracula: overlay0 / blue / pink
    readonly property color btColor:
        !enabled ? "#6272a4"
        : connected ? "#ff79c6"
        : "#bd93f9"

    readonly property string btDev: {
        const dev = devices.find(device => device.connected);
        return dev ? dev.name : "";
    }

    // battery is already a percentage (device.battery is 0..1 → ×100); prefer a
    // connected device and clamp against impossible values
    readonly property real btBat: {
        const dev = devices.find(device => device.connected && device.batteryAvailable)
            ?? devices.find(device => device.batteryAvailable);
        return dev && !isNaN(dev.battery) ? Math.max(0, Math.min(dev.battery * 100, 100)) : 0;
    }

    readonly property bool btTrust: devices.some(device => device.trusted)
}
