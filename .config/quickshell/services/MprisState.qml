pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property MprisPlayer player: null

    property MprisPlayer lastPlayer: null

    property bool mprisVisible: false

    property bool mprisArtVisible: true

    property var ignored: ["mpv", "whatsapp", "Chrome", "chromium", "firefox", "Mozilla zen", "undefined"]

    function ignorePlayer(identity) {
        if (!root.ignored.includes(identity))
            root.ignored = [...root.ignored, identity];
    }

    function unignorePlayer(identity) {
        root.ignored = root.ignored.filter(id => id !== identity);
    }

    function isIgnored(p) {
        if (!p) return true;
        return root.ignored.some(app => p.identity.includes(app) || p.desktopEntry.includes(app));
    }

    function refresh() {
        let playing = [];
        for (let p of Mpris.players.values) {
            if (root.isIgnored(p)) continue;
            if (p.isPlaying) playing.push(p);
        }

        root.mprisVisible = playing.length > 0;

        let best = null;
        let fallback = null;
        for (let p of playing) {
            fallback = p;
            if (p.trackArtist !== "") best = p;
        }
        if (best) root.player = best;
        else if (fallback) root.player = fallback;
    }

    function sendNotify() {
        let title = root.player.trackTitle || "Unknown Title";
        let artist = root.player.trackArtist || "Unknown Artist";
        let album = root.player.trackAlbum || "Unknown Album";
        let art = root.player.trackArtUrl || "audio-x-generic";
        let isMpd = root.player.identity === "Music Player Daemon";

        console.log(`Your current player: ${root.player?.identity}`);

        if (title.startsWith('Listen to music,'))
            return;

        if (isMpd) {
            Quickshell.execDetached(["bash", "-c", `pos=$(awk '/#/ {print $2}' <(mpc)); notify-send -a ncmpcpp -i "${art}" "$(mpc --format "[[󰎍    %title% \n] [     %audioformat%   $pos\n    %artist%  \n    %album%]] | [%file%]" current)"`]);
        } else {
            Quickshell.execDetached(["notify-send", "-a", "mzichi", "-i", art, `󰎍    ${title}`, `    ${artist}\n    ${album}`]);
        }
    }

    Connections {
        target: root.player
        function onPostTrackChanged() {
            const isIgnored = root.ignored.some(app => root.player.identity.includes(app) || root.player.desktopEntry.includes(app));

            if (!isIgnored && root.player)
                root.sendNotify();
        }
    }

    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onCompleted: root.refresh()
            Component.onDestruction: root.refresh()

            function onPlaybackStateChanged() {
                root.refresh();
            }
            function onIsPlayingChanged() {
                root.refresh();
            }
            function onTrackArtistChanged() {
                root.refresh();
            }
        }
    }
}
