import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.notBar.rofi.openWindows

Item {
    id: root

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
        target: 'logout'
        function toggle(): void {
            console.log("[logout] toggle -> " + !MiscState.logoutOpen);
            MiscState.logoutOpen = !MiscState.logoutOpen;
        }

        function open(): void {
            MiscState.logoutOpen = true;
        }
    }
}
