pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services

Singleton {
    id: root

    property bool activateLinux: false

    property bool toggleAppLauncher: false

    property bool toggleOpenWindows: false

    property bool toggleClipHist: false

    property bool toggleRofi: false

    // tray icons visibility — persisted so the tray survives restarts
    property bool toggleSysTray: prefs.showSysTray
    onToggleSysTrayChanged: prefs.showSysTray = toggleSysTray
    property bool toggleSettings: false

    // true while the quicksettings popup is open (used to suppress redundant music toasts)
    property bool qsOpen: false

    // fullscreen logout / timer overlay
    property bool logoutOpen: false

    property date currentDate: new Date()

    property bool showPopup: false
    // persisted preference
    property bool popupSolidBg: prefs.popupSolidBg
    onPopupSolidBgChanged: prefs.popupSolidBg = popupSolidBg

    // popup card theming — windows stay transparent project-wide; the CARD
    // switches between opaque slab and frosted glass
    readonly property bool popupGlassy: !popupSolidBg
    readonly property color popupCardBg: popupSolidBg ? "#282a36" : Qt.rgba(40 / 255, 42 / 255, 54 / 255, 0.82)

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
    // ── media / now-playing toggles (persisted) ──
    property bool showPlayerChooser: prefs.showPlayerChooser
    onShowPlayerChooserChanged: prefs.showPlayerChooser = showPlayerChooser

    property bool showShuffle: prefs.showShuffle
    onShowShuffleChanged: prefs.showShuffle = showShuffle

    property bool showLoop: prefs.showLoop
    onShowLoopChanged: prefs.showLoop = showLoop

    // ── Bar module visibility (persisted) ──
    property bool showBluetooth: prefs.showBluetooth
    onShowBluetoothChanged: prefs.showBluetooth = showBluetooth

    property bool showWifi: prefs.showWifi
    onShowWifiChanged: prefs.showWifi = showWifi

    property bool showEthernet: prefs.showEthernet
    onShowEthernetChanged: prefs.showEthernet = showEthernet

    property bool showMpris: prefs.showMpris
    onShowMprisChanged: prefs.showMpris = showMpris

    property bool showBattery: prefs.showBattery
    onShowBatteryChanged: prefs.showBattery = showBattery

    property bool showNotifTray: prefs.showNotifTray
    onShowNotifTrayChanged: prefs.showNotifTray = showNotifTray

    // wifi popup — green highlighted name for the connected network
    // (false = classic white name, only the dot marks the connection)
    property bool wifiGreenName: prefs.wifiGreenName
    onWifiGreenNameChanged: prefs.wifiGreenName = wifiGreenName

    // ethernet popup — session totals always visible (false = old behaviour,
    // totals only shown together with the traffic graphs)
    property bool showNetTotals: prefs.showNetTotals
    onShowNetTotalsChanged: prefs.showNetTotals = showNetTotals

    // workspace module flavour — true = app icons (default), false = numbers
    property bool iconWorkspaces: prefs.iconWorkspaces
    onIconWorkspacesChanged: prefs.iconWorkspaces = iconWorkspaces

    // boxy theme — master toggle: controls workspaces, tray and notifications
    property bool boxyTheme: prefs.boxyTheme
    onBoxyThemeChanged: {
        prefs.boxyTheme = boxyTheme;
        notifRadius = boxyTheme ? 0 : 10;
    }

    // show workspaces module — completely hides the workspace pills
    property bool showWorkspaces: prefs.showWorkspaces
    onShowWorkspacesChanged: prefs.showWorkspaces = showWorkspaces

    // notification font family
    property string notifFont: prefs.notifFont
    onNotifFontChanged: prefs.notifFont = notifFont

    // notification popup art size and border radius
    property int notifArtSize: prefs.notifArtSize
    onNotifArtSizeChanged: prefs.notifArtSize = notifArtSize

    property int notifRadius: prefs.notifRadius
    onNotifRadiusChanged: prefs.notifRadius = notifRadius

    // bar audio modules — output (speaker) and input (mic) can be hidden
    // independently from settings
    property bool showVolumeOut: prefs.showVolumeOut
    onShowVolumeOutChanged: prefs.showVolumeOut = showVolumeOut

    property bool showVolumeIn: prefs.showVolumeIn
    onShowVolumeInChanged: prefs.showVolumeIn = showVolumeIn

    // per-application audio streams list in the quicksettings volume card
    property bool showAppVolume: prefs.showAppVolume
    onShowAppVolumeChanged: prefs.showAppVolume = showAppVolume

    // bar mode — 0 transparent, 1 solid, 2 full-bleed.
    // Icons use this to pick soft (transparent) or bright (solid bg) colours.
    readonly property bool barSolid: BarState.barMode !== 0

    // ── persistent store for user preferences ──
    FileView {
        id: prefStore

        path: Quickshell.env("HOME") + "/.config/quickshell/prefs.json"
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: prefs

            property bool popupSolidBg: false
            property bool showSysTray: true
            property bool showMpris: false
            property bool showPlayerChooser: true
            property bool showShuffle: false
            property bool showLoop: false
            property bool wifiGreenName: true
            property bool showNetTotals: true
            property bool showBluetooth: true
            property bool showWifi: true
            property bool showEthernet: true
            property bool showBattery: true
            property bool showNotifTray: true
            property bool iconWorkspaces: true
            property bool boxyTheme: true
            property bool showWorkspaces: true
            property string notifFont: "ZedMono Nerd Font"
            property int notifArtSize: 90
            property int notifRadius: 10
            property bool showVolumeOut: true
            property bool showVolumeIn: true
            property bool showAppVolume: false
        }
    }

    // ── Avatar (shared by quicksettings + settings sidebar) ──
    readonly property string avatarPath: {
        var home = Quickshell.env("HOME") || "/home/malu";
        return home + "/.config/quickshell/assets/avatar.png";
    }
    // cache-busted url so pickers refresh the image everywhere it is shown
    property string avatarUrl: "file://" + avatarPath

    function pickAvatar(): void {
        Quickshell.execDetached(["sh", "-c", `file=$(PATH="$HOME/.nix-profile/bin:$PATH" zenity --file-selection --title="Choose Avatar" --file-filter="Images | *.png *.jpg *.jpeg *.webp" 2>/dev/null) && ` + `[ -n "$file" ] && mkdir -p ~/.config/quickshell/assets && cp "$file" ~/.config/quickshell/assets/avatar.png`]);
    }

    FileView {
        path: root.avatarPath
        watchChanges: true
        onFileChanged: root.avatarUrl = "file://" + root.avatarPath + "?" + Date.now()
    }

    readonly property var currentToplevels: Hyprland.toplevels
}
