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
    property bool toggleSettings: false

    // true while the quicksettings popup is open (used to suppress redundant music toasts)
    property bool qsOpen: false

    // fullscreen logout / timer overlay
    property bool logoutOpen: false

    property date currentDate: new Date()

    property bool showPopup: false
    property bool popupSolidBg: false

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
    property bool showCpuProcs: false
    property bool showMemProcs: false
    property bool showPlayerChooser: false
    property bool showShuffle: false
    property bool showLoop: false

    readonly property var currentToplevels: Hyprland.toplevels
}
