pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Hyprland
Singleton {
    id: root
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => !w.name.startsWith("special"))
    // readonly property var workspaces: Hyprland.workspaces.values

    // property bool isFocusedMonitor: workspaces.monitor?.name === Hyprland.focusedMonitor?.name
    property bool isFocusedMonitor: workspaces.monitor?.name === Hyprland.focusedMonitor?.name ? true : false

    property bool isFocusedActive: isFocusedMonitor && workspaces.active

    property bool workspacesPresent: Hyprland.workspaces.length > 0

    function getChunks(text) {
        let chunks = [];
        let buffer = "";  // Temporary storage for text segments

        let symbolChunkInd = {};

        let nextIsActive = false;

        for (let c of text) {
            if (c === "󰀦") {
                nextIsActive = true;
                continue;
            }

            if (!(c in symbolImgMap)) {
                buffer += c;
                nextIsActive = false;
                continue;
            }

            if (buffer.length > 0 && !/^\s*$/.test(buffer)) {
                chunks.push({
                    type: "text",
                    value: buffer
                });
                buffer = ""; // Reset text buffer
            }

            if (!(c in symbolChunkInd)) {
                // spacer between repeated icons — only after an existing icon
                if (chunks.length > 0 && chunks[chunks.length - 1].type === "icon") {
                    chunks.push({
                        type: "spacer"
                    });
                }
                symbolChunkInd[c] = chunks.length;
                chunks.push({
                    type: "icon",
                    active: nextIsActive,
                    source: `image://icon/${symbolImgMap[c]}`,
                    mult: 1 // multiplicity; how many times this symbol was seen
                });
            } else {
                chunks[symbolChunkInd[c]].mult++;
                if (nextIsActive)
                    chunks[symbolChunkInd[c]].active = true;
            }
            nextIsActive = false;
        }

        if (buffer.length > 0 && !/^\s*$/.test(buffer)) {
            chunks.push({
                type: "text",
                value: buffer
            });
        }

        return chunks;
    }

    // ── dynamic per-workspace app icons ──
    // hyprland-autoname isn't always running, so derive icons straight from
    // the workspace's clients: class (from lastIpcObject) → theme icon
    readonly property var classIconMap: {
        "kitty": "kitty",
        "foot": "foot",
        "discord": "discord",
        "webcord": "discord",
        "vesktop": "discord",
        "zen": "zen",
        "firefox": "firefox",
        "librewolf": "librewolf",
        "chrom": "google-chrome",
        "brave": "brave-browser",
        "steam": "steam",
        "spotify": "spotify-client",
        "spotube": "spotube",
        "easyeffects": "com.github.wwmm.easyeffects",
        "pwvucontrol": "com.saivert.pwvucontrol",
        "obs": "com.obsproject.Studio",
        "mpv": "mpv",
        "nautilus": "org.gnome.Nautilus",
        "dolphin": "dolphin",
        "thunar": "thunar",
        "code": "visual-studio-code",
        "emacs": "emacs",
        "neovide": "neovide",
        "telegram": "telegram",
        "signal": "signal",
        "thunderbird": "thunderbird",
        "lutris": "net.lutris.Lutris",
        "heroic": "com.heroicgameslauncher.hgl",
        "bottles": "com.usebottles.bottles",
        "inkscape": "org.inkscape.Inkscape",
        "gimp": "gimp",
        "blueman": "blueman-manager",
        "alacritty": "Alacritty",
        "wezterm": "wezterm",
        "qutebrowser": "qutebrowser",
        "zathura": "org.pwmt.zathura",
        "pavucontrol": "pavucontrol",
        "stremio": "com.stremio.Stremio",
        "freetube": "io.freetubeapp.FreeTube"
    }

    // longest substring match wins so "chrome-xyz-pwa" hits before bare rules
    function iconForClass(cls) {
        const c = (cls ?? "").toLowerCase();
        let best = null;
        let bestLen = -1;
        for (const k in classIconMap) {
            if (c.includes(k) && k.length > bestLen) {
                best = classIconMap[k];
                bestLen = k.length;
            }
        }
        if (best)
            return best;
        // games run under their own app id (steam_app_123456) — fold to steam
        if (/steam_app_\d+|^steamm?$/.test(c))
            return "steam";
        // no static rule — ask the freedesktop database before giving up
        try {
            const entry = DesktopEntries.byId(c) ?? DesktopEntries.heuristicLookup(c);
            if (entry?.icon)
                return entry.icon;
        } catch (e) {}
        // standard fallback every freedesktop theme ships
        return "application-x-executable";
    }

    // deduped [{source, count}] for every client living on this workspace;
    // rev is threaded through purely as a binding dependency so callers'
    // event-driven revision counters force re-evaluation
    function clientIconsFor(ws, rev) {
        const _ = rev;
        const out = [];
        const seen = ({});
        const tls = ws?.toplevels?.values ?? [];
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i];
            if (!t || !t.wayland)
                continue;
            const icon = iconForClass(t.lastIpcObject?.class);
            if (!icon)
                continue;
            if (seen[icon]) {
                seen[icon].count++;
                continue;
            }
            seen[icon] = {
                source: `image://icon/${icon}`,
                count: 1
            };
            out.push(seen[icon]);
        }
        return out;
    }

    // ── focused-window tracking (address granularity, from IPC events) ──
    property string _focusedAddress: ""

    // HyprlandWorkspace carries no urgent flag in this quickshell build,
    // so workspace ids with an urgent window are tracked from the socket;
    // visiting a workspace clears it
    property var _urgentWsIds: ({})

    function isUrgent(wsId) {
        return !!root._urgentWsIds[wsId];
    }

    // ── shared revision counter ──
    // single coalesced refresh source for the bar workspace widgets —
    // replaces their per-widget Connections blocks with divergent event
    // lists. widgets keep their visible-gated poll Timers calling refresh()
    // as the belt-and-suspenders fallback.
    readonly property var _listEvents: new Set([
        "workspace", "destroyworkspace", "moveworkspace", "movewindow",
        "openwindow", "closewindow", "urgent", "changefloatingmode"
    ])

    property int revision: 0

    property bool _revQueued: false

    function refresh() {
        if (_revQueued)
            return; // coalesce bursts — one pass per event-loop cycle is enough
        _revQueued = true;
        Qt.callLater(() => {
            _revQueued = false;
            root.revision++;
        });
    }

    Connections {
        target: Hyprland

        function onRawEvent(ev) {
            const n = ev.name;
            if (n === "activewindow")
                root._focusedAddress = (ev.data ?? "").split(",")[1] ?? "";
            else if (n === "activewindowv2")
                root._focusedAddress = ev.data ?? "";

            // urgency bookkeeping (tracked from socket events)
            if (n === "urgent") {
                const wsId = parseInt((ev.data ?? "").split(",")[1]);
                if (!isNaN(wsId))
                    root._urgentWsIds[wsId] = true;
            } else if (n === "workspace") {
                const wsId = parseInt(ev.data ?? "");
                if (!isNaN(wsId))
                    delete root._urgentWsIds[wsId];
            }

            // shared list-refresh signal for the workspace widgets
            if (root._listEvents.has(n))
                root.refresh();
        }
    }

    // TEMP stale-icons diagnosis — remove with [icondbg] logs
    IpcHandler {
        target: "hdbg"

        function tls(): string {
            const out = [];
            for (const ws of Hyprland.workspaces.values)
                out.push(`ws${ws.id}: ${ws.toplevels?.values.length ?? -1}tls`);
            return out.join(" | ");
        }
        function bump(): void {
            root.refresh();
        }
    }

    // per-class groups with a `focused` flag when the workspace's active
    // window belongs to that group — lets the bar dim inactive app icons
    function clientGroupsFor(ws, rev) {
        const _ = rev;
        const groups = [];
        const idx = ({});
        const tls = ws?.toplevels?.values ?? [];
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i];
            if (!t || !t.wayland)
                continue;
            const icon = iconForClass(t.lastIpcObject?.class);
            if (!icon)
                continue;
            let g = idx[icon];
            if (!g) {
                g = {
                    source: `image://icon/${icon}`,
                    count: 0,
                    focused: false
                };
                idx[icon] = g;
                groups.push(g);
            }
            g.count++;
            const addr = String(t.lastIpcObject?.address ?? "");
            if (addr.length > 0 && addr === root._focusedAddress)
                g.focused = true;
        }
        return groups;
    }

    // identity-stable cache so unrelated revisions don't churn delegates;
    // signature includes the focused flag so focus changes swap entries
    property var _groupCache: ({})   // ws.id -> {sig, icons}

    function cachedClientGroups(ws, rev) {
        const groups = clientGroupsFor(ws, rev);
        const id = ws?.id ?? -1;
        const sig = groups.map(g => g.source + ":" + g.count + ":" + g.focused).join("|");
        const entry = _groupCache[id];
        if (!entry || entry.sig !== sig) {
            _groupCache[id] = {
                sig: sig,
                icons: groups
            };
            return groups;
        }
        return entry.icons;
    }

    property var symbolImgMap: {
        "D": "extra-Dota",
        "Q": "extra-qutebrowser-svg",
        "": "extra-photos",
        "": "emacs",
        "": "extra-firefox_flat",
        "": "gvim",
        "": "extra-pdf-svg",
        // "": "extra-ironman",
        "": "com.heroicgameslauncher.hgl",
        "": "com.usebottles.bottles",
        "": "spotify-client",
        "s": "spotube",
        "": "discord",
        "": "google-chrome",
        "": "extra-scale-bluetooth",
        "": "extra-scale-gimp",
        "": "org.inkscape.Inkscape",
        "": "extra-mpv2",
        "": "extra-scale-qbittorrent",
        "": "kitty",
        "🎁": "extra-wps-presentation",
        "📂": "org.gnome.Nautilus",
        "📃": "extra-wps-spreadsheet",
        "📜": "extra-wps-office",
        "😀": "io.github.ilya_zlobintsev.LACT",
        "😆": "extra-battlenet",
        "🪛": "extra-sys5",
        "󰇥": "yazi",
        "󰈩": "extra-libreoffice_impress",
        "󰓓": "steam",
        "󰡈": "extra-freetube",
        // "󰡈": "freetube",
        "󰷈": "extra-libreoffice_writer",
        "󰽉": "extra-libreoffice_draw",
        "󱎓": "net.lutris.Lutris",
        "󱢴": "extra-dolphin",
        "Z": "zen",
        "🎵": "dog.unix.cantata.Cantata",
        "g": "gpodder",
        "🐭": "polychromatic",
        "": "extra-wozzap2",
        "O": "org.openrgb.OpenRGB",
        "F": "foot",
        "": "com.stremio.Stremio",
        "M": "chrome-ikigfogfljecogfmdkeiipdcamdbibjl-Default",
        "o": "com.obsproject.Studio",
        "💬": "cinny",
        "󰺹": "kasts",
        "L": "org.gnome.Lollypop",
        "🔈": "com.saivert.pwvucontrol",
        "f": "steam_icon_250900",
        "p": "steam_icon_1687950",
        "h": "steam_icon_1145360"
    // "": "Zoom",
    // "󰄄": "extra-scale-obs",
    // "󰊻": "teams-for-linux",
    // "󰻎": "extra-system-explorer-outline",
    // "󱍼": "extra-scale-vlc",
    }
}
