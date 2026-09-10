pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Single persistent store for ALL user preferences (settings + wallpaper/misc
// state). One JsonAdapter owns prefs.json so no service can clobber another's
// keys: every write serialises the full union of properties.
Singleton {
    id: root

    readonly property alias prefs: storeAdapter

    function write(): void {
        prefStore.writeAdapter();
    }

    FileView {
        id: prefStore

        path: Quickshell.env("HOME") + "/.config/quickshell/prefs.json"
        // Blocking sync load — with the async default, the wallpaper pick
        // (and other persisted state) races the wallpaper scan at boot: the
        // `find` usually wins, so `current` falls back to the first wallpaper
        // in the list and clobbers the stored choice (the "resets on reload /
        // reboot" bug). Sync load makes prefs.wallpaper correct from frame one.
        preload: false
        blockLoading: true
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: storeAdapter

            // ── misc / settings keys ──
            property bool popupSolidBg: true
            property bool showSysTray: true
            property bool showMpris: true
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
            property bool transparentWsBadge: false
            property string notifFont: "ZedMono Nerd Font"
            property int notifArtSize: 90
            property int notifRadius: 10
            property bool showVolumeOut: true
            property bool showVolumeIn: true
            property bool showAppVolume: false
            property bool showClock: true
            property bool showResources: true
            property bool resourcesVisible: false
            property int themeScheme: 0
            property bool wifiRadioWanted: true
            property bool btRadioWanted: true

            // ── ipc handler toggles ──
            // map target → enabled; missing targets default to enabled
            property var ipcEnabled: ({})

            // ── wallpaper keys ──
            property string wallpaper: ""
            property bool wallpaperEnabled: true
            property bool desktopClock: true
            property bool slideshowEnabled: false
            property int slideshowMinutes: 30
            property var favorites: []
            property bool rotationFavoritesOnly: false
            property string barTextTone: "auto" // "auto" | "light" | "dark" — bar text wallpaper-tone mode

            // ── hyprland settings keys ──
            property bool hyprGapsOutEnabled: true
            property int hyprGapsOutValue: 12
        }
    }

    // kick the blocking load once the whole adapter tree exists
    Component.onCompleted: prefStore.reload()
}
