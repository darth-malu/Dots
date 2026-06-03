pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: rofiMaster
    // OPENWINDOWS
    readonly property var topLevels: Hyprland.toplevels.values

    property bool toggleOpenWindows: false

    property int width: toggleAppLauncher ? 380 : 580
    property int height: 250

    function filterWindows(query) {
        if (!query)
            return topLevels;
        const lowerQuery = query.toLowerCase();
        return topLevels.filter(window => window.title.toLowerCase().includes(lowerQuery));
    }

    // CLIPHIST
    property bool toggleClipHist: false

    // APPLAUNCHER
    property bool toggleAppLauncher: false

    // Cache the values once
    readonly property var allApps: DesktopEntries.applications.values

    // readonly property var sortedApps: allApps.sort((a, b) => a.name.localeCompare(b.name))

    function filterApps(query) {
        if (!query)
            return allApps;
        const lowerQuery = query.toLowerCase();
        return allApps.filter(app => app.name.toLowerCase().includes(lowerQuery));
    }

    function toggler() {
        // Quickshell.execDetached(["notify-send", `${clipHist}`]);
        if (toggleClipHist)
            // Quickshell.execDetached(["notify-send", "This works"]);
            // TODO: -> cliphist decode
            // -> wl-copy
            toggleClipHist = !toggleClipHist;
        else if (toggleAppLauncher)
            toggleAppLauncher = !toggleAppLauncher;
        else if (toggleOpenWindows) {
            // Quickshell.execDetached(["notify-send", "This works"]);
            toggleOpenWindows = !toggleOpenWindows;
        }
    }
}
