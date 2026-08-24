pragma ComponentBehavior: Bound
import QtQuick
import qs.customItems
import qs.services

Rectangle {
    id: root
    color: "transparent"
    // collapse entirely when no tracked submap is active — a fixed-size
    // transparent Rectangle still reserves space (+ spacing) in the RowLayout
    visible: loader.active
    implicitWidth: loader.active ? 19 : 0
    implicitHeight: loader.active ? 19 : 0

    Loader {
        id: loader
        active: HyprlandService.trackedSubmaps.includes(HyprlandService.submap)
        visible: active
        anchors.centerIn: parent

        BarText {
            id: submapIcon
            text: HyprlandService.submap === "drag" ? "\uf047" : "\uf065"
            color: HyprlandService.submap === "drag" ? "pink" : "orange"
            font.pointSize: 29
        }
    }
}
