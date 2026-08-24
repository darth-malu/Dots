pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels.values

    property string event: "workspace"

    // current hyprland submap name, "" when in the default map
    property string submap: ""

    readonly property var trackedSubmaps: ["resize", "drag"]

    function handleSubmap(ev) {
        if (ev.name !== "submap")
            return;

        const name = ev.data ?? "";
        root.submap = (name === "" || name === "default") ? "" : name;
    }

    Connections {
        target: Hyprland

        function onRawEvent(ev) {
            root.handleSubmap(ev);
        }
    }
}
