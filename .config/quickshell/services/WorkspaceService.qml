pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Hyprland

Singleton {
    id: root
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => !w.name.startsWith("special"))

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
        { cls: /kitty/i,       title: /yazi/i,              icon: "kitty" },
        { cls: /kitty/i,       title: /vim/i,               icon: "application-x-executable" },
        { cls: /kitty/i,       title: /btop/i,              icon: "btop" },
        { cls: /chrome.*/,     title: /Mastodon .*/,        icon: "internet-web-browser" },
        { cls: /steam_app_\d+/,title: /Binding of Isaac: .*/,icon: "steam" },
        { cls: /steam_app_\d+/,title: /Persona/,            icon: "steam" },
        { cls: /steam_app_\d+/,title: /Hades/,              icon: "steam" },
        { cls: /steam_app_default/i, title: /[bB]attle\.net/, icon: "steam" },
        { cls: /electron/i,    title: /[fF]ree[tT]ube/,     icon: "freetube" },
        { cls: /electron/i,    title: /WhatsApp Electron/,   icon: "whatsapp" },
    ]

    // ── exclusion patterns (class regex × title regex) ──
    readonly property var excludePatterns: [
        { cls: /^$/,            title: /^$/ },
        { cls: /fcitx/i,        title: /.*/ },
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
    // class resolution prefers _clientsMap (fresh hyprctl -j clients data,
    // refetched around every window event): quickshell's HyprlandToplevel
    // .lastIpcObject is only populated on full workspace fetches, so brand-
    // new windows kept a stale/empty class — and therefore a generic icon —
    // until the whole config reloaded
    function clientIconsFor(ws, rev) {
        const _ = rev;
        const out = [];
        const seen = ({});
        const tls = ws?.toplevels?.values ?? [];
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i];
            if (!t || !t.wayland)
                continue;
            const info = root._clientsMap[root._normAddr(t.address)];
            const cls = info?.class ?? t.lastIpcObject?.class ?? "";
            const title = info?.title ?? t.lastIpcObject?.title ?? "";
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

    // ── fresh class table (address → class) ──
    // hyprctl -j clients is the only source that is correct immediately
    // after a window spawns; debounced so event bursts cost one process
    //
    // CRITICAL: hyprctl addresses carry a "0x" prefix while quickshell's
    // HyprlandToplevel.address does NOT — every lookup silently missed
    // until _normAddr() was introduced
    property var _clientsMap: ({})
    property bool _clientsFetchQueued: false

    function _normAddr(a) {
        const s = String(a ?? "");
        return s.startsWith("0x") ? s : "0x" + s;
    }

    function requestClientsFetch() {
        if (_clientsFetchQueued)
            return;
        _clientsFetchQueued = true;
        clientsDebounce.restart();
    }

    Timer {
        id: clientsDebounce

        interval: 120
        running: false
        onTriggered: hyprctlClients.running = true
    }

    Process {
        id: hyprctlClients

        command: ["hyprctl", "-j", "clients"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root._clientsFetchQueued = false;
                try {
                    const arr = JSON.parse(this.text);
                    const m = ({});
                    for (const c of arr)
                        m[c.address] = { class: c.class || c.initialClass || "", title: c.title || "" };
                    root._clientsMap = m;
                    // new classes can change icons without changing the
                    // workspace LIST — nudge the shared revision so bars redraw
                    root.refresh();
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: requestClientsFetch()

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
    readonly property var _listEvents: new Set(["workspace", "destroyworkspace", "moveworkspace", "movewindow", "openwindow", "closewindow", "urgent", "changefloatingmode"])

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

            // window metadata events → refetch classes so brand-new windows
            // get their real app icon on the very first poll tick
            if (n === "openwindow" || n === "closewindow" || n === "windowtitle" || n === "windowclass" || n === "movewindow")
                root.requestClientsFetch();
        }
    }
}
