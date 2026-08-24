pragma Singleton
import Quickshell
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
        "blueman": "blueman-manager"
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
        // standard fallback every freedesktop theme ships
        return best ?? "application-x-executable";
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
