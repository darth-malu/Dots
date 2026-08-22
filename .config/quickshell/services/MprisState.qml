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

    property bool showMprisProgress: true

    property bool hideWhenIdle: true

    property var ignored: ["mpv", "whatsapp", "Chrome", "chromium", "firefox", "Mozilla zen", "undefined"]

    function ignorePlayer(identity) {
        if (!root.ignored.includes(identity))
            root.ignored = [...root.ignored, identity];
    }

    function unignorePlayer(identity) {
        root.ignored = root.ignored.filter(id => id !== identity);
    }

    function isIgnored(p) {
        if (!p)
            return true;
        return root.ignored.some(app => p.identity.includes(app) || p.desktopEntry.includes(app));
    }

    function refresh() {
        let playing = [];
        for (let p of Mpris.players.values) {
            if (root.isIgnored(p))
                continue;
            if (p.isPlaying)
                playing.push(p);
        }

        root.mprisVisible = root.hideWhenIdle ? playing.length > 0 : Mpris.players.values.length > 0;

        let best = null;
        let fallback = null;
        for (let p of playing) {
            fallback = p;
            if (p.trackArtist !== "")
                best = p;
        }
    if (best) {
        root.player = best;
        root.lastPlayer = best;
    } else if (fallback) {
        root.player = fallback;
        root.lastPlayer = fallback;
    } else {
        root.player = null;
        // nothing playing — still remember an idle (paused) player so
        // songart / now-playing keep working right after shell startup
        for (let p of Mpris.players.values) {
            if (!root.isIgnored(p)) {
                root.lastPlayer = p;
                break;
            }
        }
    }
}

function sendNotify() {
    // fall back to the last active player so the songart toast also works while nothing is playing
    let p = root.player && !root.isIgnored(root.player) ? root.player : null;
    if (!p)
        p = root.lastPlayer && !root.isIgnored(root.lastPlayer) ? root.lastPlayer : null;
    console.log("[songart] called · player=" + (root.player?.identity ?? "null") + " lastPlayer=" + (root.lastPlayer?.identity ?? "null") + " chosen=" + (p?.identity ?? "null"));
    if (!p)
        return;
    let title = p.trackTitle || "Unknown Title";
    let artist = p.trackArtist || "Unknown Artist";
    let album = p.trackAlbum || "Unknown Album";
    let art = p.trackArtUrl || "audio-x-generic";
    let isMpd = p.identity === "Music Player Daemon";

        // console.log(`Your current player: ${root.player?.identity}`);

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
            if (!root.player)
                return;
            const isIgnored = root.ignored.some(app => root.player.identity.includes(app) || root.player.desktopEntry.includes(app));

            if (!isIgnored)
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
