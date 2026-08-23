pragma Singleton
import Quickshell

Singleton {
    property bool enableBar: true

    // 0 = floating rounded · 1 = solid slab · 2 = transparent (no bg, flush top)
    property int barStyle: 1
}
