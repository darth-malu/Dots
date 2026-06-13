pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Singleton {
    id: root

    property bool activateLinux: false

    property bool toggleAppLauncher: false

    property bool toggleOpenWindows: false

    property bool toggleClipHist: false

    property bool toggleRofi: false

    property bool toggleSysTray: false
    property bool toggleVolume: false
    property bool toggleSettings: false

    property date currentDate: new Date()

    property bool showPopup: false

    property var trackedDates: ({})
    property int trackedDatesRev: 0

    function toggleTrackedDate(year, month, day) {
        var key = year + '-' + (month < 10 ? '0' : '') + month + '-' + (day < 10 ? '0' : '') + day;
        if (trackedDates[key]) {
            delete trackedDates[key];
        } else {
            trackedDates[key] = true;
        }
        trackedDatesRev++;
    }

    function isTrackedDate(year, month, day) {
        var key = year + '-' + (month < 10 ? '0' : '') + month + '-' + (day < 10 ? '0' : '') + day;
        return trackedDates[key] === true;
    }

    property bool showGpu: false

    readonly property var currentToplevels: Hyprland.toplevels
}
