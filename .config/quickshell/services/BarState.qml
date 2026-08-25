pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enableBar: prefs.enableBar
    onEnableBarChanged: prefs.enableBar = enableBar

    // 0 = transparent (no bg, flush top)
    // 1 = solid slab (rounded, hairline border, side margins)
    // 2 = full-bleed slab (edge-to-edge, no side margins, no border)
    // 3 = colored glass (edge-to-edge, semi-transparent colored bg)
    property int barMode: prefs.barMode
    onBarModeChanged: prefs.barMode = barMode

    // legacy flag kept for older consumers/settings state
    readonly property bool solidBar: barMode === 1

    // ── persistent store ──
    FileView {
        id: prefStore

        path: Quickshell.env("HOME") + "/.config/quickshell/bar-prefs.json"
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
        }
    }
}
