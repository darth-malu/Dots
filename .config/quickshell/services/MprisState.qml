pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property MprisPlayer player: null

    property string albumArt: player?.trackArtUrl ?? ""

    property MprisPlayer lastPlayer: null

    property bool mprisVisible: false

    property bool mprisArtVisible: true

    property bool showMprisProgress: true

    property bool hideWhenIdle: true

    // scroll-to-marquee song titles (pill + quicksettings card)
    property bool marqueeEnabled: true

    // ── quicksettings card persistence ──
    // pinned player identity (set by cycling through players on the card)
    property string pinIdentity: ""

    function playerByIdentity(identity) {
        for (let p of Mpris.players.values)
            if (p.identity === identity)
                return p;
        return null;
    }

    // every player including normally-ignored ones (chrome etc.) so they
    // can be selected as the card's control target
    readonly property var controlPlayers: Mpris.players.values

    // the player the quicksettings card shows/controls — survives pause,
    // honours an explicit pin, falls back through player → lastPlayer
    readonly property MprisPlayer cardPlayer: {
        const p = root.pinIdentity.length > 0 ? root.playerByIdentity(root.pinIdentity) : null;
        return p ?? root.player ?? root.lastPlayer ?? null;
    }

    function cycleCardPin() {
        const list = root.controlPlayers;
        if (list.length === 0) {
            root.pinIdentity = "";
            return;
        }
        const cur = root.cardPlayer?.identity ?? "";
        let idx = -1;
        for (let i = 0; i < list.length; i++)
            if (list[i].identity === cur)
                idx = i;
        const next = list[(idx + 1) % list.length];
        // cycling onto the already-shown player releases the pin instead
        root.pinIdentity = next.identity === cur && root.pinIdentity.length > 0 ? "" : next.identity;
    }

    // volume nudge that works for players without MPRIS volume support —
    // chrome gets its per-application stream adjusted via wpctl
    function adjustVolume(p, up) {
        if (!p)
            return;
        if (p.volumeSupported) {
            p.volume = Math.max(0, Math.min(p.volume + (up ? 0.05 : -0.05), 1));
            return;
        }
        const kw = ((p.desktopEntry && p.desktopEntry.length > 2 ? p.desktopEntry : p.identity || "").split(" ")[0] || "").toLowerCase().replace(/[^a-z0-9]/g, "");
        if (kw.length < 3)
            return;
        Quickshell.execDetached(["sh", "-c", `id=$(wpctl status | awk -v kw='${kw}' '/^[[:space:]]*└?─? ?Streams:/{s=1;next} /^Video|^Audio|^Endpoints/{s=0} s && /^[[:space:]]*[0-9]+\\./ && index(tolower($0), kw) { match($0, /[0-9]+/); print substr($0, RSTART, RLENGTH); exit }'); ` + `[ -n "$id" ] && wpctl set-volume "$id" ${up ? "0.05+" : "0.05-"}`]);
    }

    property var ignored: ["mpv", "whatsapp", "undefined"]

    // browsers are shown like any player but must NEVER display album art
    function isBrowserPlayer(p) {
        if (!p)
            return false;
        const s = ((p.identity ?? "") + " " + (p.desktopEntry ?? "")).toLowerCase();
        return ["chrome", "chromium", "firefox", "zen"].some(k => s.includes(k));
    }

    function browserGlyph(p) {
        const s = ((p?.identity ?? "") + " " + (p?.desktopEntry ?? "")).toLowerCase();
        if (s.includes("chrome") || s.includes("chromium"))
            return "\uf268";
        return "\uf269";
    }

    // art url for a player — browsers always fall back to their icon glyph name
    function artFor(p) {
        if (!p || isBrowserPlayer(p))
            return "";
        return p.trackArtUrl ?? "";
    }

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
        if (root.isBrowserPlayer(p))
            art = dEntry || "audio-x-generic";
        // let len = p.length;
        let uid = p.uniqueId;
        let dEntry = p.desktopEntry;
        let vol = p.volumeSupported ? p.volume.toFixed(2) * 100 + "%" : "--";

        if (title.startsWith('Listen to music,'))
            return;

        Quickshell.execDetached(["notify-send", "-a", "mzichi", "-i", art, `󰎍  ${title}`, `   \n  ${artist}\n  ${album}`]);

        /* NOTE xesam
        + genre
        + disc_number
        + audio_bpm
        + user_rating
        + trackid || track_number
        */
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
