pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Hyprland

// import Quickshell.Io

Singleton {
    id: root
    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel?.wayland?.activated ? Hyprland.activeToplevel : null
    readonly property string currentWindow: activeToplevel?.title ?? ""
    readonly property bool currentMonitor: Hyprland.focusedMonitor
    /* Connections { */
    /*     target: Hyprland */

    /*     function onRawEvent(event: HyprlandEvent): void { */
    /*         const n = event.name */
    /*         if (n.endsWith("v2")) return; */

    /*         if (["openwindow", "closewindow", "movewindow"].includes(n)) { */
    /*             Hyprland.refreshToplevels() */
    /*             Hyprland.refreshWorkspaces() */
    /*         } else if (n.includes("mon")) { */
    /*             Hyprland.refreshMonitors(); */
    /*         } else if (n.includes("windows") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) { */
    /*             Hyprland.refreshToplevels(); */
    /*         } */
    /*     } */
    /* } */
}
