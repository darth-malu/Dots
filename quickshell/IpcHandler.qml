import qs.services
import QtQuick
import Quickshell.Io
import qs.notBar.rofi.openWindows

Item {
    id: root

    IpcHandler {
        target: 'mpris'

        function pauseAll(): void {
            for (const player of MprisState.players.values) {
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
            else
                pass;
        // TODO: forucs based on title of toplevel and qe
        }

        function toggleMpris(): void {
            MprisState.mprisVisible = !MprisState.mprisVisible;
        }

        function toggleMprisArt(): void {
            MprisState.mprisArtVisible = !MprisState.mprisArtVisible;
        }

        function toggleMprisIcon(): void {
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
}
