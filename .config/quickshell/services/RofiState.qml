pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

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

    // CALC
    property bool toggleCalc: false

    // Cache the values once
    readonly property var allApps: DesktopEntries.applications.values

    // readonly property var sortedApps: allApps.sort((a, b) => a.name.localeCompare(b.name))

    function filterApps(query) {
        if (!query)
            return allApps;
        const lowerQuery = query.toLowerCase();
        return allApps.filter(app => app.name.toLowerCase().includes(lowerQuery));
    }

    function close() {
        // Every rofi panel — app launcher, open windows, clipboard history,
        // calc — is its own layer surface with WlrKeyboardFocus.Exclusive.
        // Closing must drop ALL four flags: a leftover mapping where even ONE
        // panel stays visible silently swallows every key event on the session
        // until quickshell restarts. At most one should ever be open.
        toggleAppLauncher = false;
        toggleOpenWindows = false;
        toggleClipHist = false;
        toggleCalc = false;
    }

    // exclusive-focus overlay patrol — opening one rofi dismisses the other
    // rofi panels plus any picker/settings/logout overlay that could stack
    // on top and steal keyboard focus (same pattern as PickerState below).
    onToggleAppLauncherChanged: if (toggleAppLauncher) { toggleOpenWindows = false; toggleClipHist = false; toggleCalc = false; PickerState.closeAll(); MiscState.toggleSettings = false; MiscState.logoutOpen = false; }
    onToggleOpenWindowsChanged: if (toggleOpenWindows) { toggleAppLauncher = false; toggleClipHist = false; toggleCalc = false; PickerState.closeAll(); MiscState.toggleSettings = false; MiscState.logoutOpen = false; }
    onToggleClipHistChanged: if (toggleClipHist) { toggleAppLauncher = false; toggleOpenWindows = false; toggleCalc = false; PickerState.closeAll(); MiscState.toggleSettings = false; MiscState.logoutOpen = false; }
    onToggleCalcChanged: if (toggleCalc) { toggleAppLauncher = false; toggleOpenWindows = false; toggleClipHist = false; PickerState.closeAll(); MiscState.toggleSettings = false; MiscState.logoutOpen = false; }
}
