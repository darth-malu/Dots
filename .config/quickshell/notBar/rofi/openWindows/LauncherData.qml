pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    readonly property var topLevels: Hyprland.toplevels // RET list<toplevels>

    function filter(query) {
        const q = query.toLowerCase().trim();
        if (!q)
            return topLevels;

        return topLevels.values.filter(window => window.wayland.title.toLowerCase().includes(q));
    }
}
