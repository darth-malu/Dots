pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.customItems
import qs.services
import qs.themes

// Submap indicator — appears only while a tracked keybind submap is live
// (resize via SUPER+ALT+R, drag via SUPER+ALT+M), prompting the resize/move
// direction keys + ESC. Sizes like the other status pills so it never shifts
// the RHS when idle; click sends ESC to drop straight back to the global map.
// Icons: \uf065 nf-fa-expand (resize), \uf047 nf-fa-arrows (move) — rendered
// in the Symbols Nerd Font while the label uses the main bar font.
BarBlock {
    id: root

    readonly property bool isDrag: HyprlandService.submap === "drag"
    readonly property bool tracked: HyprlandService.trackedSubmaps.includes(HyprlandService.submap)
    readonly property color mainColor: root.isDrag ? Themes.pink : Themes.orange

    // no footprint in the bar unless a tracked submap is active
    visible: root.tracked

    content: RowLayout {
        spacing: 5

        Text {
            text: root.isDrag ? "\uf047" : "\uf065"
            color: root.mainColor
            font {
                pixelSize: 12
                bold: true
                family: "Symbols Nerd Font Mono"
            }
        }

        Text {
            text: root.isDrag ? "move" : "resize"
            color: root.mainColor
            font {
                pixelSize: 10
                bold: true
                family: "Quicksand Medium"
            }
        }
    }

    // click = send ESC, dropping out of the submap immediately
    onClicked: {
        if (root.tracked)
            HyprlandService.dispatch('hl.dsp.submap("reset")');
    }
}