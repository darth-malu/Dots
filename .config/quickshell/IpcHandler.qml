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

    // TEMP: debug probe for tray icon screen positions (remove after testing)
    function walkTray(item, out) {
        if (!item || typeof item !== "object" || !item.children)
            return;
        if ((item.objectName ?? "").indexOf("trayIconDelegate") >= 0) {
            const p = item.mapToGlobal(0, 0);
            out.push(`${item.tipText} x=${Math.round(p.x)} y=${Math.round(p.y)} w=${item.width} h=${item.height}`);
        }
        for (let i = 0; i < item.children.length; i++)
            walkTray(item.children[i], out);
    }

    IpcHandler {
        id: trayDebugHandler
        target: 'trayDebug'
        function positions(): string {
            const out = [];
            const wins = Quickshell.windows;
            for (const w of wins) {
                if (w?.contentItem)
                    walkTray(w.contentItem, out);
            }
            if (out.length === 0)
                out.push(`no delegates; windows=${wins.length} toggleSysTray=${MiscState.toggleSysTray}`);
            return out.join("\n");
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
