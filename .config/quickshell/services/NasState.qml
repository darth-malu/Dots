pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // NAS shares served by this machine — order defines popup row order.
    // Only meaningful on carthage; other hosts see nothing.
    readonly property bool available: QuickState.hostName === "carthage"

    readonly property var shares: [
        { name: "Hyogo", target: "/media/Hyogo", unit: "media-Hyogo.mount" },
        { name: "Mutsu", target: "/media/Mutsu", unit: "media-Mutsu.mount" },
        { name: "Yuri", target: "/media/Yuri", unit: "media-Yuri.mount" }
    ]

    // share name -> mounted bool, parsed straight from /proc/mounts
    property var mountedMap: ({})

    readonly property int unmountedCount: shares.filter(s => mountedMap[s.name] !== true).length
    readonly property bool allMounted: unmountedCount === 0

    FileView {
        id: mountsFile
        path: "/proc/mounts"
        onInternalTextChanged: root.parse()
    }

    // slow background poll so the popup never shows stale states
    Timer {
        interval: 15000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: mountsFile.reload()
    }

    // fast re-poll right after a mount/unmount click so rows react quickly
    Timer {
        id: recheck
        interval: 2000
        running: false
        repeat: true
        property int ticksLeft: 0

        onTriggered: {
            mountsFile.reload();
            ticksLeft--;
            if (ticksLeft <= 0)
                stop();
        }
    }

    function kickRecheck(ticks) {
        recheck.ticksLeft = ticks;
        recheck.restart();
    }

    function parse() {
        const text = mountsFile.text();
        const map = {};
        for (const s of root.shares)
            map[s.name] = text.includes(" " + s.target + " ");
        root.mountedMap = map;
    }

    function isMounted(share) {
        return root.mountedMap[share.name] === true;
    }

    function mount(share) {
        Quickshell.execDetached(["systemctl", "restart", share.unit]);
        root.kickRecheck(15);
    }

    function unmount(share) {
        // prefer a clean udisks unmount of whatever source backs the target,
        // fall back to stopping the systemd mount unit
        Quickshell.execDetached(["sh", "-c",
            `src=$(findmnt -n -o SOURCE --target '${share.target}' 2>/dev/null); `
            + `[ -n "$src" ] && udisksctl unmount -b "$src" 2>/dev/null || systemctl stop '${share.unit}'`]);
        root.kickRecheck(15);
    }

    // remount everything that is missing
    function mountAll() {
        for (const s of root.shares)
            if (!root.isMounted(s))
                Quickshell.execDetached(["systemctl", "restart", s.unit]);
        root.kickRecheck(20);
    }
}
