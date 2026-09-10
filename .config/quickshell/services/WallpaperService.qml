pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property string current: Prefs.prefs.wallpaper
    onCurrentChanged: {
        Prefs.prefs.wallpaper = current;
        if (current.length > 0 && root.toneFor(current) === "unknown")
            root._probeLum(current);
        Prefs.write();
    }
    property bool enabled: Prefs.prefs.wallpaperEnabled
    onEnabledChanged: {
        Prefs.prefs.wallpaperEnabled = enabled;
        Prefs.write();
    }
    property bool desktopClock: Prefs.prefs.desktopClock
    onDesktopClockChanged: {
        Prefs.prefs.desktopClock = desktopClock;
        Prefs.write();
    }

    // bar text: three-way wallpaper-tone selector — "auto" (default) follows
    // each wallpaper's detected tone so glyphs stay legible (dark walls →
    // light glyphs, bright walls → dark glyphs); "light" pins to a light
    // wallpaper (dark glyphs); "dark" pins to a dark wallpaper (light glyphs)
    property string barTextTone: Prefs.prefs.barTextTone ?? "auto"
    onBarTextToneChanged: {
        Prefs.prefs.barTextTone = barTextTone;
        Prefs.write();
    }

    // ── auto-rotate slideshow ──
    property bool slideshowEnabled: Prefs.prefs.slideshowEnabled
    onSlideshowEnabledChanged: {
        Prefs.prefs.slideshowEnabled = slideshowEnabled;
        Prefs.write();
    }

    property int slideshowMinutes: Prefs.prefs.slideshowMinutes
    onSlideshowMinutesChanged: {
        Prefs.prefs.slideshowMinutes = slideshowMinutes;
        Prefs.write();
    }

    // rotate only through starred favorites instead of the whole library
    property bool rotationFavoritesOnly: Prefs.prefs.rotationFavoritesOnly
    onRotationFavoritesOnlyChanged: {
        Prefs.prefs.rotationFavoritesOnly = rotationFavoritesOnly;
        Prefs.write();
    }

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

    // tone of a wallpaper path: "light" / "dark" from its folder, else "unknown"
    function toneFor(path) {
        if (!path)
            return "unknown";
        const i = path.lastIndexOf("/");
        const parent = i > 0 ? path.slice(0, i) : "";
        if (parent.endsWith("/light"))
            return "light";
        if (parent.endsWith("/dark"))
            return "dark";
        return "unknown";
    }

    // ── light/dark awareness ──
    // known directly from the folder when the wallpaper lives in light/ dark/;
    // otherwise probed once via a 1x1 ImageMagick average (perceptual luma).
    // Results are cached PER PATH so switching wallpapers never reuses a
    // stale classification from a previously-probed image.
    property var _toneCache: ({})    // path -> bool (is light)
    property string _lumPath: ""

    readonly property bool lightWallpaper: {
        const t = root.toneFor(root.current);
        if (t === "light")
            return true;
        if (t === "dark")
            return false;
        return root._toneCache[root.current] === true;
    }

    function _probeLum(path) {
        if (!path || path.length === 0 || root._toneCache[path] !== undefined)
            return;
        root._lumPath = path;
        lumProc.buf = "";
        lumProc.command = ["sh", "-c", "magick \"$1\" -auto-orient -resize 1x1! -format '%[fx:int(round(255*(0.2126*r+0.7152*g+0.0722*b)))]' info: 2>/dev/null", "sh", path];
        lumProc.running = true;
    }

    Process {
        id: lumProc
        property string buf: ""
        running: false
        stdout: SplitParser {
            onRead: data => {
                const v = parseInt(data.trim(), 10);
                if (!isNaN(v) && root._lumPath.length > 0) {
                    var c = Object.assign({}, root._toneCache);
                    c[root._lumPath] = v > 128;
                    root._toneCache = c;
                }
            }
        }
        onExited: code => {
            if (code !== 0 && root._lumPath.length > 0) {
                var c = Object.assign({}, root._toneCache);
                c[root._lumPath] = false;
                root._toneCache = c;
            }
            root._lumPath = "";
        }
    }

    // move a wallpaper into the light/ or dark/ folder (used by the picker)
    property string _mvSrc: ""
    property string _mvDest: ""

    function moveToTone(path, tone) {
        if (!path || path.length === 0 || (tone !== "light" && tone !== "dark"))
            return;
        if (root.toneFor(path) === tone)
            return;
        root._mvSrc = path;
        root._mvDest = root.wallpaperDirPath + "/" + tone + "/" + path.split("/").pop();
        // plain force move: always relocates (a same-named file in the target
        // folder is replaced — allocation is a pure file move, nothing else)
        mvProc.command = ["sh", "-c", "mkdir -p \"$1\" && mv -f \"$2\" \"$3\"", "sh", root.wallpaperDirPath + "/" + tone, path, root._mvDest];
        mvProc.running = true;
    }

    Process {
        id: mvProc
        running: false
        onExited: code => {
            if (code !== 0)
                return;
            root._applyMovedFile(root._mvSrc, root._mvDest);
        }
    }

    // in-place move: swap the path and re-sort instead of a full re-scan, so
    // the grid keeps its delegates (no blank re-decode flash, no thumbnail storm).
    // Only touches `current` when the moved file IS the applied wallpaper — and
    // then just re-points it to the relocated copy (same image, never a new one);
    // allocation never applies/sets a different wallpaper.
    function _applyMovedFile(src: string, dest: string): void {
        const i = root.wallpaperList.indexOf(src);
        if (i < 0) {
            root._refreshList();
            return;
        }
        // keep any favorites that pointed at the old path pointed at the new
        // one — a move relocates the file but the user's star must survive
        const favIdx = root.favorites.indexOf(src);
        if (favIdx >= 0) {
            const nextFavs = root.favorites.slice();
            nextFavs[favIdx] = dest;
            root.favorites = nextFavs;
            Prefs.prefs.favorites = nextFavs;
        }
        const next = root.wallpaperList.slice();
        next[i] = dest;
        // no re-sort: keeping the item at its old index means the tile never
        // jumps to a new grid slot when it crosses the light/dark folder line
        root.wallpaperList = next;
        if (root.current === src)
            root.current = dest;
        Prefs.write();
        root._warmThumbs();
    }

    // delete a wallpaper file (picker header) — if it was the applied one,
    // fall through to the next wallpaper in the list, else clear it
    property string _rmPath: ""

    function removeWallpaper(path: string): void {
        if (!path || path.length === 0)
            return;
        root._rmPath = path;
        rmProc.command = ["sh", "-c", "rm -f -- \"$1\"", "sh", path];
        rmProc.running = true;
    }

    Process {
        id: rmProc
        running: false
        onExited: code => {
            if (code !== 0)
                return;
            if (root.current === root._rmPath) {
                const i = root.wallpaperList.indexOf(root._rmPath);
                const next = root.wallpaperList[i + 1] ?? root.wallpaperList[i - 1] ?? "";
                if (next.length > 0)
                    root.setWallpaper(next);
                else
                    root.current = "";
            }
            root._refreshList();
            root._rmPath = "";
        }
    }

    // per-tone counts for the picker / settings display
    function countTone(tone: string): int {
        let n = 0;
        const list = root.wallpaperList;
        for (let i = 0; i < list.length; i++)
            if (root.toneFor(list[i]) === tone)
                n++;
        return n;
    }

    // accumulator for the wallpaper-listing process
    property var _acc: []

    // scans BOTH the flat dir AND its light/ dark/ subfolders — the folder
    // name is what tags each wallpaper's tone for the text provider
    Process {
        id: lsProc
        command: ["sh", "-c", "find " + root.wallpaperDirPath + " -maxdepth 2 -type f \\( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name '*.bmp' \\) | sort"]

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
