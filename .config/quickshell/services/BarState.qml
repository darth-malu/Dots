pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enableBar: prefs.enableBar
    onEnableBarChanged: prefs.enableBar = enableBar

    // false = transparent (no bg, flush top) · true = solid slab
    property bool solidBar: prefs.solidBar
    onSolidBarChanged: prefs.solidBar = solidBar

    // ── persistent store ──
    FileView {
        id: prefStore

        path: Quickshell.env("HOME") + "/.config/quickshell/bar-prefs.json"
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: prefs

            property bool enableBar: true
            property bool solidBar: false
        }
    }
}
