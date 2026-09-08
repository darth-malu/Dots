pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Reads the real Hyprland settings straight out of the user's lua config
// (~/.config/hypr/general.lua + decoration.lua) — the files ARE the source of
// truth here, because this Hyprland build rejects the legacy `hyprctl keyword`
// ipc request entirely. Applying a change therefore repairs the lua in place
// (a perl regex swap) and then fires `hyprctl reload` (verified working) to
// push it live, so every edit is persisted across restarts.
Singleton {
    id: root

    readonly property string generalPath: Quickshell.env("HOME") + "/.config/hypr/general.lua"
    readonly property string decorationPath: Quickshell.env("HOME") + "/.config/hypr/decoration.lua"

    property bool loaded: false

    // current file values
    property int gapsIn: 6
    property int gapsOut: 12
    property int borderSize: 1
    property int rounding: 4
    property color activeBorder: "#00abf5"
    property color inactiveBorder: "#595959"

    // gaps-out master switch — persisted in prefs.json so the "off" state
    // survives restarts; the file value is forced to 0 while off
    property bool gapsOutEnabled: Prefs.prefs.hyprGapsOutEnabled

    property string _buf: ""

    // re-read the files after an apply so the UI tracks the reloaded truth
    function reload(): void {
        reader.running = false;
        root._buf = "";
        reader.command = ["sh", "-c", "cat \"$1\" && printf '\\n__DECOR__\\n' && cat \"$2\"", "sh",
            root.generalPath, root.decorationPath];
        reader.running = true;
    }

    function _parse(buf): void {
        const gi = buf.match(/gaps_in\s*=\s*(\d+)/);
        if (gi) root.gapsIn = parseInt(gi[1], 10);
        const go = buf.match(/gaps_out\s*=\s*(\d+)/);
        if (go) root.gapsOut = parseInt(go[1], 10);
        const bs = buf.match(/border_size\s*=\s*(\d+)/);
        if (bs) root.borderSize = parseInt(bs[1], 10);
        const rnd = buf.match(/rounding\s*=\s*(\d+)/);
        if (rnd) root.rounding = parseInt(rnd[1], 10);
        const ab = buf.match(/active_border\s*=\s*\{[^}]*"rgba\(([0-9A-Fa-f]{8})\)"/);
        if (ab) root.activeBorder = "#" + ab[1].slice(0, 6);
        const ib = buf.match(/inactive_border\s*=\s*"rgba\(([0-9A-Fa-f]{8})\)"/);
        if (ib) root.inactiveBorder = "#" + ib[1].slice(0, 6);
    }

    Process {
        id: reader
        running: false

        stdout: SplitParser {
            onRead: data => {
                root._buf += data + "\n";
            }
        }

        onExited: code => {
            if (code === 0)
                root._parse(root._buf);
            root._buf = "";
            root.loaded = true;
        }
    }

    // perl-edits a config file in place, then reloads Hyprland so the value
    // applies immediately — the only live path on this lua-based build
    function _apply(file: string, expr: string): void {
        Quickshell.execDetached(["sh", "-c", "perl -0pi -e '" + expr + "' '" + file + "' && hyprctl reload"]);
        resyncTimer.restart();
    }

    Timer {
        id: resyncTimer
        interval: 650
        onTriggered: root.reload()
    }

    // integer setters — HyprStepRow nudges call these (key = property name)
    function applyInt(key: string, value: int): bool {
        switch (key) {
        case "gapsIn":
            root.gapsIn = value;
            root._apply(root.generalPath, "s/gaps_in\\s*=\\s*\\d+/gaps_in = " + value + "/");
            return true;
        case "gapsOut":
            root.gapsOut = value;
            Prefs.prefs.hyprGapsOutValue = value;
            Prefs.write();
            root._apply(root.generalPath, "s/gaps_out\\s*=\\s*\\d+/gaps_out = " + value + "/");
            return true;
        case "borderSize":
            root.borderSize = value;
            root._apply(root.generalPath, "s/border_size\\s*=\\s*\\d+/border_size = " + value + "/");
            return true;
        case "rounding":
            root.rounding = value;
            root._apply(root.decorationPath, "s/rounding\\s*=\\s*\\d+/rounding = " + value + "/");
            return true;
        }
        return false;
    }

    // border-color setters — hex is "#RRGGBB" from the palette, stored as
    // "rgba(RRGGBBAA)" in the lua
    function applyBorder(key: string, hex: string): bool {
        const rgba8 = ((hex || "").replace("#", "") + "ff").toUpperCase();
        if (!/^[0-9A-F]{8}$/.test(rgba8))
            return false;
        if (key === "activeBorder") {
            root.activeBorder = hex;
            root._apply(root.generalPath,
                "s/(active_border\\s*=\\s*\\{[^\"]*\"rgba\\()[0-9A-Fa-f]{8}(\\)\")/${1}" + rgba8 + "$2/");
            return true;
        }
        if (key === "inactiveBorder") {
            root.inactiveBorder = hex;
            root._apply(root.generalPath,
                "s/(inactive_border\\s*=\\s*\"rgba\\()[0-9A-Fa-f]{8}(\\)\")/${1}" + rgba8 + "$2/");
            return true;
        }
        return false;
    }

    // master gaps-out switch: off forces gaps_out to 0, on restores the
    // last preferred value (stored in prefs) and persists the choice
    function setGapsOutEnabled(on: bool): void {
        if (on === root.gapsOutEnabled)
            return;
        Prefs.prefs.hyprGapsOutEnabled = on;
        Prefs.write();
        root.gapsOutEnabled = on;
        const v = on ? Prefs.prefs.hyprGapsOutValue : 0;
        root.gapsOut = v;
        root._apply(root.generalPath, "s/gaps_out\\s*=\\s*\\d+/gaps_out = " + v + "/");
    }

    Component.onCompleted: root.reload()
}