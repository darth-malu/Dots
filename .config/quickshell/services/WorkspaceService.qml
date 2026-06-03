pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Hyprland

Singleton {
    id: root
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => !w.name.startsWith("special"))
    // readonly property var workspaces: Hyprland.workspaces.values

    // property bool isFocusedMonitor: workspaces.monitor?.name === Hyprland.focusedMonitor?.name
    property bool isFocusedMonitor: workspaces.monitor?.name === Hyprland.focusedMonitor?.name ? true : false

    property bool isFocusedActive: isFocusedMonitor && workspaces.active

    property bool workspacesPresent: Hyprland.workspaces.length > 0
}
