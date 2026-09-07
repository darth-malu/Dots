pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property string current: Prefs.prefs.wallpaper
    onCurrentChanged: Prefs.prefs.wallpaper = current

    property bool enabled: Prefs.prefs.wallpaperEnabled
    onEnabledChanged: Prefs.prefs.wallpaperEnabled = enabled

    property bool desktopClock: Prefs.prefs.desktopClock
    onDesktopClockChanged: Prefs.prefs.desktopClock = desktopClock

    // ── auto-rotate slideshow ──
    property bool slideshowEnabled: Prefs.prefs.slideshowEnabled
    onSlideshowEnabledChanged: Prefs.prefs.slideshowEnabled = slideshowEnabled

    property int slideshowMinutes: Prefs.prefs.slideshowMinutes
    onSlideshowMinutesChanged: Prefs.prefs.slideshowMinutes = slideshowMinutes

    // rotate only through starred favorites instead of the whole library
    property bool rotationFavoritesOnly: Prefs.prefs.rotationFavoritesOnly
    onRotationFavoritesOnlyChanged: Prefs.prefs.rotationFavoritesOnly = rotationFavoritesOnly

    // ── favorites (persisted paths) ──
    property var favorites: Prefs.prefs.favorites ?? []

    function toggleFavorite(path: string): void {
        if (path.length === 0)
            return;
        var idx = root.favorites.indexOf(path);
        var next = root.favorites.slice();
        if (idx >= 0)
            next.splice(idx, 1);
        else
            next.push(path);
        root.favorites = next;
        Prefs.prefs.favorites = next;
        Prefs.write();
    }

    function isFavorite(path: string): bool {
        return root.favorites.indexOf(path) >= 0;
    }

    property var wallpaperList: []
    property int _currentIndex: -1

    // the pool rotation steps through — favorites only when that mode is on
    // and at least one favorite exists, otherwise the full library
    function _rotationList(): var {
        if (root.rotationFavoritesOnly && root.favorites.length > 0) {
            var favs = [];
            for (var i = 0; i < root.wallpaperList.length; i++) {
                if (root.isFavorite(root.wallpaperList[i]))
                    favs.push(root.wallpaperList[i]);
            }
            return favs;
        }
        return root.wallpaperList;
    }

    function setWallpaper(path: string): void {
        if (path.length === 0)
            return;
        current = path;
        _currentIndex = wallpaperList.indexOf(path);
    }

    function nextWallpaper(): void {
        var list = root._rotationList();
        if (list.length === 0)
            return;
        var i = list.indexOf(root.current);
        if (i < 0)
            i = -1;
        i = (i + 1) % list.length;
        current = list[i];
        _currentIndex = wallpaperList.indexOf(current);
    }

    function prevWallpaper(): void {
        var list = root._rotationList();
        if (list.length === 0)
            return;
        var i = list.indexOf(root.current);
        if (i < 0)
            i = 0;
        i = (i - 1 + list.length) % list.length;
        current = list[i];
        _currentIndex = wallpaperList.indexOf(current);
    }

    readonly property string wallpaperDirPath: Quickshell.env("HOME") + "/.config/quickshell/wallpapers"

    // accumulator for the wallpaper-listing process
    property var _acc: []

    Process {
        id: lsProc
        command: ["sh", "-c", "find " + root.wallpaperDirPath + " -maxdepth 1 -type f \\( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name '*.bmp' \\) | sort"]

        stdout: SplitParser {
            onRead: data => {
                var p = data.trim();
                if (p.length > 0)
                    root._acc.push(p);
            }
        }

        onExited: code => {
            if (code !== 0)
                return;
            root.wallpaperList = root._acc;
            root._acc = [];
            if (root.current.length === 0 && root.wallpaperList.length > 0) {
                root._currentIndex = 0;
                root.current = root.wallpaperList[0];
            } else {
                root._currentIndex = root.wallpaperList.indexOf(root.current);
            }
            root._warmThumbs();
        }
    }

    function _refreshList(): void {
        lsProc.running = false;
        lsProc.running = true;
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.enabled
        onTriggered: _refreshList()
    }

    // auto-rotate — advances to the next wallpaper every interval
    Timer {
        id: slideshowTimer
        interval: root.slideshowMinutes * 60000
        repeat: true
        running: root.enabled && root.slideshowEnabled && root._rotationList().length > 1
        onTriggered: root.nextWallpaper()
    }

    // ── thumbnail cache — small jpgs so pickers / settings load fast ──
    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpapers"
    property var thumbReady: ({})
    property int thumbVersion: 0

    function _thumbPath(path: string): string {
        if (path.length === 0)
            return "";
        var base = path.split("/").pop();
        var dot = base.lastIndexOf(".");
        return root.thumbDir + "/" + (dot >= 0 ? base.slice(0, dot) : base) + ".jpg";
    }

    // returns cached thumb if it exists yet, otherwise the original image
    function thumbSource(path: string, version): string {
        return root.thumbReady[path] ? root._thumbPath(path) : path;
    }

    function _warmThumbs() {
        var list = root.wallpaperList;
        if (list.length === 0)
            return;
        thumbProc.buf = "";
        thumbProc.command = ["sh", "-c", root.thumbScript, "sh", root.thumbDir].concat(list);
        thumbProc.running = true;
    }

    readonly property string thumbScript: `dir="$1"; shift; mkdir -p "$dir"; while [ "$#" -gt 0 ]; do f="$1"; shift; [ -f "$f" ] || continue; b="\${f##*/}"; b="\${b%.*}"; out="$dir/$b.jpg"; if [ ! -f "$out" ]; then magick "$f" -auto-orient -thumbnail '480x270^' -gravity center -extent 480x270 -quality 82 "$out" 2>/dev/null || continue; fi; printf '%s\n' "$f"; done`

    Process {
        id: thumbProc
        property string buf: ""

        stdout: SplitParser {
            onRead: data => thumbProc.buf += data
        }

        onExited: code => {
            if (code !== 0)
                return;
            var lines = thumbProc.buf.split("\n");
            var next = {};
            for (var key in root.thumbReady)
                next[key] = true;
            for (var i = 0; i < lines.length; i++) {
                var p = lines[i].trim();
                if (p.length > 0)
                    next[p] = true;
            }
            root.thumbReady = next;
            root.thumbVersion++;
        }
    }

    Component.onCompleted: _refreshList()
}
