pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property MprisPlayer player: null

    property MprisPlayer lastPlayer: null

    property bool mprisVisible: true

    property bool mprisArtVisible: true

    property var players: new Set()

    property list<string> ignored: ["mpv", "whatsapp", "Chrome", "chromium", "firefox", "Mozilla zen", "undefined"]

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
            // console.log(`Your current player: ${root.player?.identity}`);
            const isIgnored = root.ignored.some(app => root.player.identity.includes(app) || root.player.desktopEntry.includes(app));

            if (!isIgnored && root.player)
                root.sendNotify();
        }
    }

    function updatePlayer() {
        let backup, leader = null;

        for (let player of Mpris.players.values) {
            const isIgnored = root.ignored.some(app => player.identity.includes(app) || player.desktopEntry.includes(app));
            // console.log(`Your current player: ${root.player?.identity}`);

            if (isIgnored)
                continue;
            else if (player.isPlaying) {
                backup = player;
                if (player?.trackArtist !== "")
                    leader = player;
            }
        }
        player = leader != null ? leader : backup;
    }

    function handlePlayerChanged(player: MprisPlayer) {
        if (!player.isPlaying)
            return;

        players.delete(player);
        players.add(player);
        lastPlayer = player ?? null;

        updatePlayer();
    }

    function playerDestroyed(player: MprisPlayer) {
        players.delete(player);
        lastPlayer = players[players.size] ?? null;

        updatePlayer();
    }

    Instantiator {
        model: Mpris.players    // ObjectModel: <MprisPlayer>

        Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onCompleted: root.handlePlayerChanged(modelData)
            Component.onDestruction: root.playerDestroyed(modelData)

            function onPlaybackStateChanged() {
                root.handlePlayerChanged(modelData);
                if (modelData.isPlaying) {
                    root.mprisVisible = true;
                } else {
                    root.mprisVisible = false;
                }
            }
        }
    }
}
