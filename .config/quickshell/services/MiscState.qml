pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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

    // ── Bar module visibility ──
    property bool showBluetooth: true
    property bool showWifi: true
    property bool showEthernet: true
    property bool showBattery: true

    // ── Avatar (shared by quicksettings + settings sidebar) ──
    readonly property string avatarPath: {
        var home = Quickshell.env("HOME") || "/home/malu";
        return home + "/.config/quickshell/assets/avatar.png";
    }
    // cache-busted url so pickers refresh the image everywhere it is shown
    property string avatarUrl: "file://" + avatarPath

    function pickAvatar(): void {
        Quickshell.execDetached(["sh", "-c",
            `file=$(PATH="$HOME/.nix-profile/bin:$PATH" zenity --file-selection --title="Choose Avatar" --file-filter="Images | *.png *.jpg *.jpeg *.webp" 2>/dev/null) && `
            + `[ -n "$file" ] && mkdir -p ~/.config/quickshell/assets && cp "$file" ~/.config/quickshell/assets/avatar.png`]);
    }

    FileView {
        path: root.avatarPath
        watchChanges: true
        onFileChanged: root.avatarUrl = "file://" + root.avatarPath + "?" + Date.now()
    }

    readonly property var currentToplevels: Hyprland.toplevels
}
