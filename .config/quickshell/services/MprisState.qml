pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    property MprisPlayer player: null

    property string albumArt: player?.trackArtUrl ?? ""

    property MprisPlayer lastPlayer: null

    property bool mprisVisible: false

    // setting any of these is only remembered if the store is flushed to disk —
    // assigning the JsonAdapter property alone never persists
    function persistPrefs(): void {
        prefStore.writeAdapter();
    }

    property bool mprisArtVisible: prefs.mprisArtVisible
    onMprisArtVisibleChanged: { prefs.mprisArtVisible = mprisArtVisible; root.persistPrefs(); }

    property bool showMprisProgress: prefs.showMprisProgress
    onShowMprisProgressChanged: { prefs.showMprisProgress = showMprisProgress; root.persistPrefs(); }

    property bool hideWhenIdle: prefs.hideWhenIdle
    onHideWhenIdleChanged: { prefs.hideWhenIdle = hideWhenIdle; root.persistPrefs(); }

    // scroll-to-marquee song titles (pill + quicksettings card)
    property bool marqueeEnabled: prefs.marqueeEnabled
    onMarqueeEnabledChanged: { prefs.marqueeEnabled = marqueeEnabled; root.persistPrefs(); }

    // pill default view — compact (icon + thin progress ring only) or the
    // full artwork/title layout; hovering the compact pill expands it
    property bool mprisCompact: prefs.mprisCompact
    onMprisCompactChanged: { prefs.mprisCompact = mprisCompact; root.persistPrefs(); }

    // ── persistent store ──
    FileView {
        id: prefStore

        path: Quickshell.env("HOME") + "/.config/quickshell/mpris-prefs.json"
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: prefs

            property bool marqueeEnabled: true
            property bool mprisCompact: true
            property bool mprisArtVisible: true
            property bool showMprisProgress: true
            property bool hideWhenIdle: true
        }
    }

    // ── quicksettings card persistence ──
    // pinned player handle (dbusName). identity alone is NOT unique — a
    // browser registers multiple MPRIS players sharing the same name — and
    // uniqueId collapses across players in this build, so the pin tracks the
    // player's stable, per-instance DBus bus name instead. "" = no pin.
    property string pinPlayerName: ""

    function playerByName(name) {
        for (let p of root.controlPlayers)
            if (p.dbusName === name)
                return p;
        return null;
    }

    // every player including normally-ignored ones (chrome etc.) so they
    // can be selected as the card's control target
    readonly property var controlPlayers: Mpris.players.values

    // the subset a user may actually pick in the quicksettings chooser —
    // players they "deleted" (ignored) drop out of this list
    readonly property var pickablePlayers: root.controlPlayers.filter(p => !root.isIgnored(p))

    // the player the quicksettings card shows/controls — survives pause,
    // honours an explicit pin, falls back through player → lastPlayer
    readonly property MprisPlayer cardPlayer: {
        const p = root.pinPlayerName.length > 0 ? root.playerByName(root.pinPlayerName) : null;
        return p ?? root.player ?? root.lastPlayer ?? null;
    }

    function cycleCardPin() {
        const list = root.controlPlayers;
        if (list.length === 0) {
            root.pinPlayerName = "";
            return;
        }
        const cur = root.cardPlayer?.dbusName ?? "";
        let idx = -1;
        for (let i = 0; i < list.length; i++)
            if (list[i].dbusName === cur)
                idx = i;
        // stepping always hands the card to the landed player;
        // release happens by clicking the current row again
        const next = list[(idx + 1) % list.length];
        root.pinPlayerName = next.dbusName;
    }

    // step the card's player forward/back through the chooser strip
    // (wheel scrolling); every stop pins that player
    function moveCardPin(dir) {
        const list = root.controlPlayers;
        if (list.length === 0)
            return;
        const cur = root.cardPlayer?.dbusName ?? "";
        let idx = -1;
        for (let i = 0; i < list.length; i++)
            if (list[i].dbusName === cur)
                idx = i;
        if (idx === -1)
            idx = dir > 0 ? 0 : list.length - 1;
        else
            idx = (idx + dir + list.length) % list.length;
        root.pinPlayerName = list[idx].dbusName;
    }

    // right-click on the switcher — pin the first player that is actually playing
    function jumpToPlaying() {
        const playing = root.controlPlayers.filter(p => !root.isIgnored(p) && p.isPlaying);
        if (playing.length > 0)
            root.pinPlayerName = playing[0].dbusName;
    }

    // per-app glyph for the switcher button — shows which app the card controls
    function appGlyph(p) {
        const s = ((p?.identity ?? "") + " " + (p?.desktopEntry ?? "")).toLowerCase();
        if (s.includes("spotify"))
            return "\uf1bc";
        if (s.includes("chrome") || s.includes("chromium"))
            return "\uf268";
        if (s.includes("firefox") || s.includes("zen"))
            return "\uf269";
        return "\uf001";
    }

    // brand accent per player — drives the bar ring + center glyph (and the
    // volume flash) so the module reads as "owned" by the active app.
    // returns a QColor (or undefined → caller falls back to the theme pink)
    function brandColor(p) {
        const s = ((p?.identity ?? "") + " " + (p?.desktopEntry ?? "")).toLowerCase();
        if (s.includes("spotify"))
            return "#1db954";
        if (s.includes("chrome") || s.includes("chromium"))
            return "#4285f4";
        if (s.includes("firefox") || s.includes("zen"))
            return "#ff7139";
        if (s.includes("mpd"))
            return "#e3a3c7";   // music player daemon — soft pastel
        if (s.includes("discord") || s.includes("music"))
            return "#5865f2";
        if (s.includes("mpv") || s.includes("player"))
            return "#ff5f56";
        return undefined;
    }

    // wpctl pipeline that resolves a player's sink-input id by keyword
    function wpStreamLookup(kw) {
        return `id=$(wpctl status | awk -v kw='${kw}' '/^[[:space:]]*└?─? ?Streams:/{s=1;next} /^Video|^Audio|^Endpoints/{s=0} s && /^[[:space:]]*[0-9]+\\./ && index(tolower($0), kw) { match($0, /[0-9]+/); print substr($0, RSTART, RLENGTH); exit }'); `;
    }

    // short app keyword used to find a player's stream in wpctl
    function streamKeyword(p) {
        const kw = ((p.desktopEntry && p.desktopEntry.length > 2 ? p.desktopEntry : p.identity || "").split(" ")[0] || "").toLowerCase().replace(/[^a-z0-9]/g, "");
        return kw.length >= 3 ? kw : "";
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
        const kw = streamKeyword(p);
        if (!kw)
            return;
        Quickshell.execDetached(["sh", "-c", wpStreamLookup(kw) + `[ -n "$id" ] && wpctl set-volume "$id" ${up ? "0.05+" : "0.05-"}`]);
    }

    // per-player mute — MPRIS volume snaps to 0 and back to the last level;
    // players without MPRIS volume fall back to wpctl mute on their stream
    property var savedVolume: ({})

    function isMuted(p) {
        if (!p)
            return false;
        return p.volumeSupported ? p.volume <= 0 : false;
    }

    function toggleMute(p) {
        if (!p)
            return;
        if (p.volumeSupported) {
            if (p.volume > 0) {
                root.savedVolume[p.identity] = p.volume;
                p.volume = 0;
            } else {
                const v = root.savedVolume[p.identity];
                p.volume = (v && v > 0 && v <= 1) ? v : 0.5;
            }
            return;
        }
        const kw = streamKeyword(p);
        if (!kw)
            return;
        Quickshell.execDetached(["sh", "-c", wpStreamLookup(kw) + `[ -n "$id" ] && wpctl set-mute "$id" toggle`]);
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

    // ── playback progress with silent-restart handling ──
    // some players (mostly chromium/youtube) don't re-report Position or
    // Seeked when the SAME track restarts, which pins the interpolated
    // position at length. progress() owns a tiny mutable state object per
    // consumer (bar ring / popup row / lock card) so each one can detect:
    //   · track fingerprint change         → trust freshly reported position
    //   · position jumps backwards         → trust freshly reported position
    //   · playing while pinned at length  → time the restarted pass itself,
    //     synthesising 0..1 so the indicator walks, then wraps, forever.
    function progressState(): var {
        return { fp: "", lastRaw: -1, synth: false, synthPos: 0, lastTick: 0 };
    }

    function _fpOf(p): string {
        const md = p?.metadata ?? null;
        if (!md)
            return "";
        return String((md["mpris:trackid"] ?? "") + "|" + (md["xesam:url"] ?? ""));
    }

    // fraction 0..1 of how far through the current pass the player is
    function progress(p, st, isPlaying): real {
        if (!p || !(p.length > 0)) {
            st.lastRaw = -1;
            st.fp = "";
            if (typeof st.synth !== "undefined")
                st.synth = false;
            return 0;
        }
        const len = p.length;
        const raw = p.position ?? 0;
        const now = Date.now();

        // new pass: a changed fingerprint means a new track (or a repeat that
        // got a fresh trackid) — reset and trust whatever the player reports
        const fp = root._fpOf(p);
        if (fp !== st.fp) {
            st.fp = fp;
            st.lastRaw = -1;
            st.synth = false;
            st.synthPos = 0;
            st.lastTick = now;
            return Math.max(0, Math.min(raw / len, 1));
        }

        // accrue real playback time since the last tick (clamped against dt
        // surges from sleeps/drag); only while actually playing
        const dt = (st.lastTick > 0 && isPlaying) ? Math.min(Math.max((now - st.lastTick) / 1000, 0), 2) : 0;
        st.lastTick = now;

        // player still stuck after a silent restart, so we're numbering a pass
        // with our own clock until it starts reporting fresh data again
        if (st.synth) {
            if (raw < len) {
                // caught up — hand back control to the real position
                st.synth = false;
                st.synthPos = raw;
                st.lastRaw = -1;
                return Math.max(0, Math.min(raw / len, 1));
            }
            st.synthPos = Math.max(0, st.synthPos + dt);
            if (st.synthPos > len)
                st.synthPos -= len; // another silent repeat mid-pass
            st.lastRaw = -1; // the pasted-at-length raw is never a real baseline
            return Math.max(0, Math.min(st.synthPos / len, 1));
        }

        // paused/stopped — the frozen position is the truth
        if (!isPlaying) {
            st.lastRaw = raw;
            return Math.max(0, Math.min(raw / len, 1));
        }

        // a backward jump while playing means the host restarted (or seeked
        // back) — resume from the freshly reported value
        if (st.lastRaw >= 0 && raw < st.lastRaw - 2.0) {
            st.lastRaw = -1;
            st.synth = false;
            st.synthPos = 0;
            return Math.max(0, Math.min(raw / len, 1));
        }

        // hit/parked at the end while still playing → the host forgot to report
        // the loop; begin timing this fresh pass ourselves
        if (raw >= len) {
            st.synth = true;
            st.synthPos = 0;
            st.lastRaw = -1;
            return 0;
        }

        st.lastRaw = raw;
        return Math.max(0, Math.min(raw / len, 1));
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
        return root.ignored.some(app => p.identity.includes(app) || (p.desktopEntry ?? "").includes(app));
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

        // a pinned player clamps the selection in place — auto-selection must
        // not chase playback changes while a pin is active (both the card and
        // the bar track root.player); it falls back only once the pinned
        // player disappears
        const pinned = root.pinPlayerName.length > 0 ? root.playerByName(root.pinPlayerName) : null;
        if (pinned) {
            if (root.player !== pinned)
                root.player = pinned;
            root.lastPlayer = pinned;
            return;
        }

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
            // nothing playing — still remember an idle (paused) player so
            // songart / now-playing keep working right after shell startup
            let idle = null;
            for (let p of Mpris.players.values) {
                if (!root.isIgnored(p)) {
                    idle = p;
                    break;
                }
            }
            root.lastPlayer = idle;
            // when we're not hiding on idle, keep the pill showing the last
            // available player instead of collapsing to nothing
            root.player = root.hideWhenIdle ? null : idle;
        }
    }

    // fire-and-forget: when a player starts playing, pause ANY other player
    // that was already playing — one active sink at a time.
    function pauseOthers(p) {
        if (!p || !p.isPlaying)
            return;
        for (const other of Mpris.players.values) {
            if (other !== p && other.isPlaying && other.canPause)
                other.pause();
        }
    }

    function sendNotify() {
        // fall back to the last active player so the songart toast also works while nothing is playing
        let p = root.player && !root.isIgnored(root.player) ? root.player : null;
        if (!p)
            p = root.lastPlayer && !root.isIgnored(root.lastPlayer) ? root.lastPlayer : null;
        // console.log("[songart] called · player=" + (root.player?.identity ?? "null") + " lastPlayer=" + (root.lastPlayer?.identity ?? "null") + " chosen=" + (p?.identity ?? "null"));
        if (!p)
            return;

        let title = p.trackTitle || "Unknown Title";
        let artist = p.trackArtist || "Unknown Artist";
        let album = p.trackAlbum || "Unknown Album";
        let uid = p.uniqueId;
        let dEntry = p.desktopEntry;
        // browsers never expose art — fall back to their desktop entry icon
        let art = root.isBrowserPlayer(p) ? (dEntry || "audio-x-generic") : (p.trackArtUrl || "audio-x-generic");
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
            const p = root.player;
            const isIgnored = root.ignored.some(app => p.identity.includes(app) || (p.desktopEntry ?? "").includes(app));
            // browsers spam a toast per video/short — only real players
            // announce tracks automatically (manual songArt still works)
            if (!isIgnored && !root.isBrowserPlayer(p))
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
                root.pauseOthers(modelData);
            }
            function onIsPlayingChanged() {
                root.refresh();
                root.pauseOthers(modelData);
            }
            function onTrackArtistChanged() {
                root.refresh();
            }
        }
    }
}
