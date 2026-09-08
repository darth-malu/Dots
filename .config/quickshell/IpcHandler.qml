import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.notBar.rofi.openWindows

Item {
    id: root

    // force-load SpeedtestState so its speedtest IPC target exists at startup
    property bool _preloadSpeedtest: SpeedtestState.running

    IpcHandler {
        target: 'mpris'

        function pauseAll(): void {
            for (const player of Mpris.players.values) {
                if (player.canPause)
                    player.pause();
            }
        }

        function togglePlaying(): void {
            const player = MprisState.player;
            if (player && player.canTogglePlaying) {
                player.togglePlaying();
            }
        }

        function previous(): void {
            const player = MprisState.player;
            if (player && player.canGoPrevious)
                player.previous();
        }

        function next(): void {
            const player = MprisState.player;
            if (player && player.canGoNext)
                player.next();
        }

        function raise(): void {
            const player = MprisState.player;
            if (player && player.canRaise)
                player.raise();
            // TODO: focus based on title of toplevel
        }

        function toggleMpris(): void {
            MprisState.mprisVisible = !MprisState.mprisVisible;
        }

        function toggleMprisArt(): void {
            MprisState.mprisArtVisible = !MprisState.mprisArtVisible;
        }

        function songArt(): void {
            MprisState.sendNotify();
        }
    }

    IpcHandler {
        target: 'pipewire'
        function mute(): void {
            PipewireState.inputSink.audio.muted = !PipewireState.inputSink.audio.muted; // NOTE works but mute status not bound
        }
    }

    IpcHandler {
        target: 'notifications'
        function dismissAll(): void {
            NotificationState.dismissAll();
        }

        function showLast(): void {
            NotificationState.showLastNotif(NotificationState.lastNotif);
        }
    }

    IpcHandler {
        target: 'brightness'
        function get(): string {
            return BrightnessState.pctDisplay.toString();
        }

        function set(pct: string): void {
            BrightnessState.setLevel(parseInt(pct) || 0);
        }

        function adjust(delta: string): void {
            const d = parseInt(delta) || 0;
            BrightnessState.setLevel(BrightnessState.pctDisplay + d);
        }
    }

    IpcHandler {
        target: 'netspeed'
        function toggleNet(): void {
            NetworkState.netspeedVisible = !NetworkState.netspeedVisible;
        }
    }

    IpcHandler {
        target: 'resources'
        function toggleResources(): void {
            ResourcesState.resourcesVisible = !ResourcesState.resourcesVisible;
        }
    }

    IpcHandler {
        target: 'bar'
        function toggleBar(): void {
            BarState.enableBar = !BarState.enableBar;
        }
    }

    IpcHandler {
        target: 'appLauncher'
        function toggle(): void {
            RofiState.toggleAppLauncher = !RofiState.toggleAppLauncher;
        }
    }

    IpcHandler {
        target: 'activate'
        function toggle(): void {
            MiscState.activateLinux = !MiscState.activateLinux;
        }
    }

    IpcHandler {
        target: 'openWindows'
        function toggle(): void {
            RofiState.toggleOpenWindows = !RofiState.toggleOpenWindows;
        }
    }

    IpcHandler {
        target: 'clipHist'
        function toggle(): void {
            RofiState.toggleClipHist = !RofiState.toggleClipHist;
        }
    }

    IpcHandler {
        target: 'calc'
        function toggle(): void {
            // calculators are overlay-exclusive — drop any other open rofi
            RofiState.toggleAppLauncher = false;
            RofiState.toggleOpenWindows = false;
            RofiState.toggleClipHist = false;
            RofiState.toggleCalc = !RofiState.toggleCalc;
        }
    }

    IpcHandler {
        target: 'SysTray'
        function toggle(): void {
            MiscState.toggleSysTray = !MiscState.toggleSysTray;
        }
    }

    IpcHandler {
        target: 'emoji'
        function toggle(): void {
            PickerState.emojiOpen = !PickerState.emojiOpen;
        }
    }

    IpcHandler {
        target: 'color'
        function toggle(): void {
            PickerState.colorOpen = !PickerState.colorOpen;
        }

        // straight-to-eyedropper shortcut
        function screenPick(): string {
            PickerState.colorOpen = false;
            Quickshell.execDetached(["sh", "-c", "hyprpicker | tr -d '\\n' | wl-copy && notify-send -a Color -t 1500 'color copied to clipboard'"]);
            return "picking…";
        }
    }

    IpcHandler {
        target: 'wallpaperPicker'
        function toggle(): void {
            PickerState.wallpaperOpen = !PickerState.wallpaperOpen;
        }

        function open(): void {
            PickerState.wallpaperOpen = true;
        }
    }

    IpcHandler {
        target: 'logout'
        function toggle(): void {
            // console.log("[logout] toggle -> " + !MiscState.logoutOpen);
            MiscState.logoutOpen = !MiscState.logoutOpen;
        }

        function open(): void {
            MiscState.logoutOpen = true;
        }
    }

    IpcHandler {
        target: 'notes'
        function add(): void {
            NotesState.addNote();
        }

        function clear(): void {
            NotesState.clear();
        }
    }

    IpcHandler {
        target: 'wallpaper'
        function toggle(): void {
            WallpaperService.enabled = !WallpaperService.enabled;
        }

        function next(): void {
            WallpaperService.nextWallpaper();
        }

        function prev(): void {
            WallpaperService.prevWallpaper();
        }

        function set(path: string): void {
            WallpaperService.setWallpaper(path);
        }

        function current(): string {
            return WallpaperService.current;
        }

        function toggleClock(): void {
            WallpaperService.desktopClock = !WallpaperService.desktopClock;
        }
    }

    // ── per-handler on/off toggles (Settings → Help) ──
    readonly property var handlerModel: [
        { target: "mpris", icon: "\uf001", label: "MPRIS" },
        { target: "pipewire", icon: "\uf028", label: "PipeWire" },
        { target: "notifications", icon: "\uf0f3", label: "Notifications" },
        { target: "brightness", icon: "\uf185", label: "Brightness" },
        { target: "netspeed", icon: "\uf0e8", label: "Net speed" },
        { target: "resources", icon: "\uf1c0", label: "Resources" },
        { target: "bar", icon: "\uf0c9", label: "Bar" },
        { target: "appLauncher", icon: "\uf0ae", label: "App launcher" },
        { target: "activate", icon: "\uf023", label: "Activate Linux" },
        { target: "openWindows", icon: "\uf108", label: "Open windows" },
        { target: "clipHist", icon: "\uf0c5", label: "Clipboard history" },
        { target: "calc", icon: "\uf1ec", label: "Calculator" },
        { target: "SysTray", icon: "\uf2d0", label: "SysTray" },
        { target: "emoji", icon: "\uf118", label: "Emoji picker" },
        { target: "color", icon: "\uf53f", label: "Color picker" },
        { target: "wallpaperPicker", icon: "\uf87c", label: "Wallpaper picker" },
        { target: "logout", icon: "\uf08b", label: "Logout overlay" },
        { target: "wallpaper", icon: "\uf87c", label: "Wallpaper" }
    ]

    function ipcEnabled(target: string): bool {
        const v = Prefs.prefs.ipcEnabled[target];
        return v === undefined ? true : !!v;
    }

    function setIpcEnabled(target: string, on: bool): void {
        const map = {};
        for (const k in Prefs.prefs.ipcEnabled)
            map[k] = Prefs.prefs.ipcEnabled[k];
        map[target] = on;
        Prefs.prefs.ipcEnabled = map;
        const children = root.data;
        for (let i = 0; i < children.length; i++) {
            const h = children[i];
            if (h && h.target === target) {
                h.enabled = on;
                break;
            }
        }
        Prefs.write();
    }

    // apply persisted toggles on (re)load — once here, settings toggles and
    // process restarts stay in sync
    Component.onCompleted: {
        const map = Prefs.prefs.ipcEnabled;
        const children = root.data;
        for (let i = 0; i < children.length; i++) {
            const h = children[i];
            if (!h || !h.target)
                continue;
            const v = map[h.target];
            if (v !== undefined)
                h.enabled = v;
        }
    }
}
