pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool enableBar: prefs.enableBar
    onEnableBarChanged: prefs.enableBar = enableBar

    // 0 = transparent (no bg, flush top)
    // 1 = solid margin slab (rounded, hairline border, side margins)
    // 2 = solid slab (edge-to-edge, no side margins, no border)
    // 3 = colored glass (edge-to-edge, semi-transparent colored bg)
    property int barMode: prefs.barMode
    onBarModeChanged: prefs.barMode = barMode

    // caelestia-style desktop frame — accent outline around the screen
    property bool frameOn: prefs.frameOn
    onFrameOnChanged: prefs.frameOn = frameOn

    // legacy flag kept for older consumers/settings state
    readonly property bool solidBar: barMode === 1

    // ── persistent store ──
    FileView {
        id: prefStore

        path: Quickshell.env("HOME") + "/.config/quickshell/bar-prefs.json"
        // Blocking sync load (matching GitState): with the async default the
        // window would build in transparent mode first and flip to the stored
        // mode on arrival — a visible re-layout/artifact on qs restart.
        preload: false
        blockLoading: true
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: prefs

            property bool enableBar: true
            // legacy boolean — seeds barMode on first load; once an explicit
            // mode is stored the binding is broken and this key is ignored
            property bool solidBar: false
            // no stored value yet → derive from the old boolean (migration)
            property int barMode: prefs.solidBar ? 1 : 0
            property bool frameOn: true
        }
    }

    Component.onCompleted: prefStore.reload()
}
