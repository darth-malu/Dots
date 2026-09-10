pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Networking
import qs.services

Singleton {
    id: root

    property bool activateLinux: false

    property bool toggleAppLauncher: false

    property bool toggleOpenWindows: false

    property bool toggleClipHist: false

    property bool toggleRofi: false

    // tray icons visibility — persisted so the tray survives restarts
    property bool toggleSysTray: Prefs.prefs.showSysTray
    onToggleSysTrayChanged: {
        Prefs.prefs.showSysTray = toggleSysTray;
        Prefs.write();
    }
    property bool toggleSettings: false

    // true while the quicksettings popup is open (used to suppress redundant music toasts)
    property bool qsOpen: false

    // fullscreen logout / timer overlay
    property bool logoutOpen: false

    property date currentDate: new Date()

    property bool showPopup: false
    // persisted preference
    property bool popupSolidBg: Prefs.prefs.popupSolidBg
    onPopupSolidBgChanged: {
        Prefs.prefs.popupSolidBg = popupSolidBg;
        Prefs.write();
    }

    // popup card theming — windows stay transparent project-wide; the CARD
    // switches between opaque slab and frosted glass
    property int popupTheme: Prefs.prefs.popupTheme
    onPopupThemeChanged: {
        Prefs.prefs.popupTheme = popupTheme;
        Prefs.write();
    }
    property real popupOpacity: Prefs.prefs.popupOpacity / 100
    onPopupOpacityChanged: {
        Prefs.prefs.popupOpacity = Math.round(popupOpacity * 100);
        Prefs.write();
    }
    readonly property bool popupGlassy: !popupSolidBg

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

    property bool showCpuProcs: false
    property bool showMemProcs: false
    // ── media / now-playing toggles (persisted) ──
    property bool showPlayerChooser: Prefs.prefs.showPlayerChooser
    onShowPlayerChooserChanged: {
        Prefs.prefs.showPlayerChooser = showPlayerChooser;
        Prefs.write();
    }

    property bool showShuffle: Prefs.prefs.showShuffle
    onShowShuffleChanged: {
        Prefs.prefs.showShuffle = showShuffle;
        Prefs.write();
    }

    property bool showLoop: Prefs.prefs.showLoop
    onShowLoopChanged: {
        Prefs.prefs.showLoop = showLoop;
        Prefs.write();
    }

    // ── Bar module visibility (persisted) ──
    property bool showBluetooth: Prefs.prefs.showBluetooth
    onShowBluetoothChanged: {
        Prefs.prefs.showBluetooth = showBluetooth;
        Prefs.write();
    }

    property bool showWifi: Prefs.prefs.showWifi
    onShowWifiChanged: {
        Prefs.prefs.showWifi = showWifi;
        Prefs.write();
    }

    property bool showEthernet: Prefs.prefs.showEthernet
    onShowEthernetChanged: {
        Prefs.prefs.showEthernet = showEthernet;
        Prefs.write();
    }

    property bool showMpris: Prefs.prefs.showMpris
    onShowMprisChanged: {
        Prefs.prefs.showMpris = showMpris;
        Prefs.write();
    }

    property bool showBattery: Prefs.prefs.showBattery
    onShowBatteryChanged: {
        Prefs.prefs.showBattery = showBattery;
        Prefs.write();
    }

    property bool showNotifTray: Prefs.prefs.showNotifTray
    onShowNotifTrayChanged: {
        Prefs.prefs.showNotifTray = showNotifTray;
        Prefs.write();
    }

    // wifi popup — green highlighted name for the connected network
    // (false = classic white name, only the dot marks the connection)
    property bool wifiGreenName: Prefs.prefs.wifiGreenName
    onWifiGreenNameChanged: {
        Prefs.prefs.wifiGreenName = wifiGreenName;
        Prefs.write();
    }

    // ethernet popup — session totals always visible (false = old behaviour,
    // totals only shown together with the traffic graphs)
    property bool showNetTotals: Prefs.prefs.showNetTotals
    onShowNetTotalsChanged: {
        Prefs.prefs.showNetTotals = showNetTotals;
        Prefs.write();
    }

    // workspace module flavour — true = app icons (default), false = numbers
    property bool iconWorkspaces: Prefs.prefs.iconWorkspaces
    onIconWorkspacesChanged: {
        Prefs.prefs.iconWorkspaces = iconWorkspaces;
        Prefs.write();
    }

    // transparent active workspace number badge (parent container stays colored)
    property bool transparentWsBadge: Prefs.prefs.transparentWsBadge
    onTransparentWsBadgeChanged: {
        Prefs.prefs.transparentWsBadge = transparentWsBadge;
        Prefs.write();
    }

    // boxy theme — master toggle: controls workspaces, tray and notifications
    property bool boxyTheme: Prefs.prefs.boxyTheme
    onBoxyThemeChanged: {
        Prefs.prefs.boxyTheme = boxyTheme;
        notifRadius = boxyTheme ? 0 : 10;
        Prefs.write();
    }

    // show workspaces module — completely hides the workspace pills
    property bool showWorkspaces: Prefs.prefs.showWorkspaces
    onShowWorkspacesChanged: {
        Prefs.prefs.showWorkspaces = showWorkspaces;
        Prefs.write();
    }

    // notification font family
    property string notifFont: Prefs.prefs.notifFont
    onNotifFontChanged: {
        Prefs.prefs.notifFont = notifFont;
        Prefs.write();
    }

    // notification popup art size and border radius
    property int notifArtSize: Prefs.prefs.notifArtSize
    onNotifArtSizeChanged: {
        Prefs.prefs.notifArtSize = notifArtSize;
        Prefs.write();
    }

    property int notifRadius: Prefs.prefs.notifRadius
    onNotifRadiusChanged: {
        Prefs.prefs.notifRadius = notifRadius;
        Prefs.write();
    }

    // bar audio modules — output (speaker) and input (mic) can be hidden
    // independently from settings
    property bool showVolumeOut: Prefs.prefs.showVolumeOut
    onShowVolumeOutChanged: {
        Prefs.prefs.showVolumeOut = showVolumeOut;
        Prefs.write();
    }

    property bool showVolumeIn: Prefs.prefs.showVolumeIn
    onShowVolumeInChanged: {
        Prefs.prefs.showVolumeIn = showVolumeIn;
        Prefs.write();
    }

    // per-application audio streams list in the quicksettings volume card
    property bool showAppVolume: Prefs.prefs.showAppVolume
    onShowAppVolumeChanged: {
        Prefs.prefs.showAppVolume = showAppVolume;
        Prefs.write();
    }

    // bar clock — completely hides the clock widget when off
    property bool showClock: Prefs.prefs.showClock
    onShowClockChanged: {
        Prefs.prefs.showClock = showClock;
        Prefs.write();
    }

    // performance resource blocks (disk · memory · cpu) in the bar
    property bool showResources: Prefs.prefs.showResources
    onShowResourcesChanged: {
        Prefs.prefs.showResources = showResources;
        Prefs.write();
    }

    // bar mode — 0 transparent, 1 solid, 2 full-bleed.
    // Icons use this to pick soft (transparent) or bright (solid bg) colours.
    readonly property bool barSolid: BarState.barMode !== 0

    // color scheme — 0 pyrple (default), 1 gron teal, 2 gruvbox, 3 rose pink, 4 everforest green, 5 soramane sky
    property int themeScheme: Prefs.prefs.themeScheme
    onThemeSchemeChanged: {
        Prefs.prefs.themeScheme = themeScheme;
        Prefs.write();
    }

    // ── rofi / launcher look (settings → launcher) ──
    property bool rofiBlur: Prefs.prefs.rofiBlur
    onRofiBlurChanged: {
        Prefs.prefs.rofiBlur = rofiBlur;
        Prefs.write();
    }
    // stored as percent int; exposed as a 0..1 factor for the rgba math
    property real rofiOpacity: Prefs.prefs.rofiOpacity / 100
    onRofiOpacityChanged: {
        Prefs.prefs.rofiOpacity = Math.round(rofiOpacity * 100);
        Prefs.write();
    }
    property int rofiRadius: Prefs.prefs.rofiRadius
    onRofiRadiusChanged: {
        Prefs.prefs.rofiRadius = rofiRadius;
        Prefs.write();
    }
    // -1 = auto (follow the active scheme), else an explicit scheme index 0..5
    property int rofiTheme: Prefs.prefs.rofiTheme
    onRofiThemeChanged: {
        Prefs.prefs.rofiTheme = rofiTheme;
        Prefs.write();
    }

    // ── radio states persisted across reboots (settings → connections) ──
    // wifi radio matter — `wifiEnabled` on NetworkState is !Networking.wifiEnabled
    property bool wifiRadioWanted: Prefs.prefs.wifiRadioWanted
    onWifiRadioWantedChanged: {
        Prefs.prefs.wifiRadioWanted = wifiRadioWanted;
        Prefs.write();
    }

    property bool btRadioWanted: Prefs.prefs.btRadioWanted
    onBtRadioWantedChanged: {
        Prefs.prefs.btRadioWanted = btRadioWanted;
        Prefs.write();
    }

    function setWifiRadio(on) {
        root.wifiRadioWanted = on;
        NetworkState.setWifiEnabled(on);
    }

    function setBtRadio(on) {
        root.btRadioWanted = on;
        if (Bt.adapter)
            Bt.adapter.enabled = on;
    }

    // apply the persisted radio states once the adapters come up at boot
    Timer {
        id: radioReconcile

        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            var done = true;
            if (Bt.adapter) {
                if (Bt.enabled !== root.btRadioWanted)
                    Bt.adapter.enabled = root.btRadioWanted;
            } else {
                done = false;
            }
            if (Networking.wifiEnabled !== root.wifiRadioWanted) {
                NetworkState.setWifiEnabled(root.wifiRadioWanted);
            }
            if (root.count >= 15 || (done && Networking.wifiEnabled === root.wifiRadioWanted))
                radioReconcile.stop();
            root.count++;
        }
    }
    property int count: 0

    // ── Avatar (shared by quicksettings + settings sidebar) ──
    readonly property string avatarPath: {
        var home = Quickshell.env("HOME");
        return home + "/.config/quickshell/assets/avatar.png";
    }
    // cache-busted url so pickers refresh the image everywhere it is shown
    property string avatarUrl: "file://" + avatarPath

    function pickAvatar(): void {
        PickerState.avatarOpen = true;
    }

    // copy the chosen image into place (the FileView below bumps avatarUrl),
    // then dismiss the picker
    function applyAvatar(path): void {
        if (!path || path.length === 0)
            return;
        Quickshell.execDetached(["sh", "-c", `[ -f "$1" ] && mkdir -p "$HOME/.config/quickshell/assets" && cp "$1" "$HOME/.config/quickshell/assets/avatar.png"`, "sh", path]);
        PickerState.avatarOpen = false;
    }

    FileView {
        path: root.avatarPath
        watchChanges: true
        onFileChanged: root.avatarUrl = "file://" + root.avatarPath + "?" + Date.now()
    }

    readonly property var currentToplevels: Hyprland.toplevels
}
