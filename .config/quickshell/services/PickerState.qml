pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shared state for the emoji + color pickers:
// · visibility toggles (IPC / keybind driven)
// · recent emojis & colors persisted across reloads/restarts
Singleton {
    id: root

    property bool emojiOpen: false
    property bool colorOpen: false
    property bool wallpaperOpen: false
    property bool avatarOpen: false

    function closeAll() {
        root.emojiOpen = false;
        root.colorOpen = false;
        root.wallpaperOpen = false;
        root.avatarOpen = false;
    }

    // opening one picker dismisses the others — they share the overlay layer
    onEmojiOpenChanged: if (emojiOpen) {
        colorOpen = false;
        wallpaperOpen = false;
        avatarOpen = false;
    }
    onColorOpenChanged: if (colorOpen) {
        emojiOpen = false;
        wallpaperOpen = false;
        avatarOpen = false;
    }
    onWallpaperOpenChanged: if (wallpaperOpen) {
        emojiOpen = false;
        colorOpen = false;
        avatarOpen = false;
    }
    onAvatarOpenChanged: if (avatarOpen) {
        emojiOpen = false;
        colorOpen = false;
        wallpaperOpen = false;
    }

    // ── persistent store ──
    FileView {
        id: prefStore

        path: Quickshell.env("HOME") + "/.config/quickshell/picker-prefs.json"
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: prefs

            property var recentEmojis: []
            property var recentColors: []
            property string wallpaperBorder: ""
        }
    }

    // most-recent-first emoji chars, capped at 24
    readonly property var recentEmojis: prefs.recentEmojis ?? []

    function pushRecentEmoji(char) {
        const next = [char, ...recentEmojis.filter(e => e !== char)].slice(0, 24);
        if (next.length === recentEmojis.length && next[0] === recentEmojis[0])
            return;
        prefs.recentEmojis = next;
        prefStore.writeAdapter();
    }

    // most-recent-first "#rrggb" strings, capped at 18
    readonly property var recentColors: prefs.recentColors ?? []

    function pushRecentColor(hex) {
        const c = hex.toLowerCase();
        const next = [c, ...recentColors.filter(e => e !== c)].slice(0, 18);
        if (next[0] === recentColors[0] && next.length === recentColors.length)
            return;
        prefs.recentColors = next;
        prefStore.writeAdapter();
    }

    // wallpaper-picker tile ring color ("" = use the theme default)
    readonly property string wallpaperBorder: prefs.wallpaperBorder ?? ""

    function setWallpaperBorder(hex) {
        prefs.wallpaperBorder = String(hex ?? "").trim();
        prefStore.writeAdapter();
    }
}
