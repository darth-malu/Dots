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
                if (chunks[chunks.length - 1].type == "icon") {
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
