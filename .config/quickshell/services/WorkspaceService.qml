pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Hyprland

Singleton {
    id: root

    // ── dynamic per-workspace app icons ──
    // class → freedesktop icon; title-in-class overrides take priority
    readonly property var classIconMap: {
        "kitty": "kitty",
        "foot": "foot",
        "discord": "discord",
        "zen": "zen",
        "firefox": "firefox",
        "librewolf": "librewolf",
        "chrom": "google-chrome",
        "steam": "steam",
        "spotify": "spotify-client",
        "spotube": "spotube",
        "easyeffects": "com.github.wwmm.easyeffects",
        "pwvucontrol": "com.saivert.pwvucontrol",
        "obs": "com.obsproject.Studio",
        "mpv": "mpv",
        "nautilus": "org.gnome.Nautilus",
        "dolphin": "dolphin",
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
        "dota": "steam_icon_570",
        "blueman": "blueman-manager",
        "qutebrowser": "qutebrowser",
        "zathura": "org.pwmt.zathura",
        "pavucontrol": "pavucontrol",
        "stremio": "com.stremio.Stremio",
        "freetube": "freetube"
    }

    // longest substring match wins so "chrome-xyz-pwa" hits before bare rules
    function iconForClass(cls) {
        const c = (cls ?? "").toLowerCase(); // Incase of blank entry
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

    // ── title-in-class overrides ──
    // icon values are literal nerd-font / emoji chars — NOT escape sequences
    readonly property var titleClassOverrides: [
        {
            cls: /kitty/i,
            title: /yazi/i,
            icon: "yazi"
        },
        {
            cls: /kitty/i,
            title: /vim/i,
            icon: "gvim"
        },
        {
            cls: /kitty/i,
            title: /btop/i,
            icon: "btop"
        },
        {
            cls: /electron/i,
            title: /[fF]ree[tT]ube/,
            icon: "freetube"
        },
        {
            cls: /electron/i,
            title: /WhatsApp Electron/,
            icon: "whatsapp"
        },
    ]

    // ── exclusion patterns (class regex × title regex) ──
    readonly property var excludePatterns: [
        {
            cls: /^$/,
            title: /^$/
        },
        {
            cls: /fcitx/i,
            title: /.*/
        },
    ]

    function isExcluded(cls, title) {
        const c = cls ?? "";
        const t = title ?? "";
        for (const ex of root.excludePatterns) {
            if (ex.cls.test(c) && ex.title.test(t))
                return true;
        }
        return false;
    }

    function iconForClient(cls, title) {
        const c = cls ?? "";
        const t = title ?? "";
        // title-in-class overrides first (highest priority)
        for (const ov of root.titleClassOverrides) {
            if (ov.cls.test(c) && ov.title.test(t))
                return ov.icon;
        }
        return root.iconForClass(c);
    }

    // deduped [{source, count}] for every client living on this workspace;
    // rev is threaded through purely as a binding dependency so callers'
    // event-driven revision counters force re-evaluation
    //
    // class comes from the socket-maintained _classMap; quickshell never
    // stores class on HyprlandToplevel (it only shows up in lastIpcObject
    // after a full fetch), so pre-existing windows fall back to that while
    // brand-new ones are covered by the "openwindow" event. title is read
    // from the native live binding (kept fresh by windowtitlev2).
    function clientIconsFor(ws, rev) {
        const _ = rev;
        const out = [];
        const seen = ({});
        const tls = ws?.toplevels?.values ?? [];
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i];
            if (!t || !t.wayland)
                continue;
            const cls = root._classMap[root._normAddr(t.address)] ?? t.lastIpcObject?.class ?? "";
            const title = t.title ?? t.lastIpcObject?.title ?? "";
            if (root.isExcluded(cls, title))
                continue;
            const icon = iconForClient(cls, title);
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

    // ── event-driven class table (address → class) ──
    // the class is only ever carried by the "openwindow" event — quickshell
    // itself never stores it on HyprlandToplevel (it lives solely in
    // lastIpcObject from a full j/clients fetch). Tracking it here from the
    // socket removes every hyprctl spawn: new windows get their icon on the
    // very first refresh, pre-existing ones fall back to lastIpcObject.
    property var _classMap: ({})

    // quickshell fires its own initial j/clients fetch on connect; watching
    // its toplevel model guarantees an icon pass once pre-existing windows
    // load, without spawning anything ourselves (open/close also change the
    // count, but those are already handled by the events below).
    readonly property int _toplevelCount: Hyprland.toplevels.values.length
    on_ToplevelCountChanged: root.refresh()

    // CRITICAL: hyprctl addresses carry a "0x" prefix while quickshell's
    // HyprlandToplevel.address does NOT — every lookup silently missed
    // until _normAddr() was introduced later in the module history
    function _normAddr(a) {
        const s = String(a ?? "");
        return s.startsWith("0x") ? s : "0x" + s;
    }

    // ── shared revision counter ──
    // single coalesced refresh source for the bar workspace widgets —
    // replaces their per-widget Connections blocks with divergent event
    // lists. quickshell applies every event to its native Hyprland models
    // before rawEvent reaches QML, so by the time we refresh() the data is
    // already settled — no safety-net polling needed.
    readonly property var _listEvents: new Set(["workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "moveworkspace", "moveworkspacev2", "movewindow", "movewindowv2", "openwindow", "closewindow", "windowtitle", "windowtitlev2", "monitoradded", "monitoraddedv2", "monitorremoved", "changefloatingmode"])

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

            // class table — "openwindow" is the only event carrying the class,
            // indexed openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE (commas in the
            // title are fine because parse() knows the argument count)
            if (n === "openwindow") {
                const p = ev.parse(4);
                if (p.length >= 3)
                    root._classMap[root._normAddr(p[0])] = p[2];
            } else if (n === "closewindow") {
                const p = ev.parse(1);
                if (p.length >= 1)
                    delete root._classMap[root._normAddr(p[0])];
            }

            // shared list-refresh signal for the workspace widgets
            if (root._listEvents.has(n))
                root.refresh();
        }
    }
}
