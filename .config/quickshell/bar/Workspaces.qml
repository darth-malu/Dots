pragma ComponentBehavior: Bound
import QtQuick
import qs.themes
import qs.customItems
import qs.services
import Quickshell.Hyprland
import QtQuick.Layouts

RowLayout {
    id: root

    spacing: 5
    // breathing room before the next module (active window)
    // Layout.rightMargin: 12

    // belt and suspenders for list freshness: the shared WorkspaceService
    // revision bumps on socket events, a short poll catches anything missed.
    // the cache keeps array identity stable between real changes so the
    // Repeater never churns its delegates.
    readonly property int wsRev: WorkspaceService.revision

    Timer {
        interval: 750
        running: root.visible
        repeat: true
        onTriggered: WorkspaceService.refresh()
    }

    // property string _listSig: ""
    // property var _listCache: []

    readonly property var workspaceList: {
        const rev = wsRev; // dependency
        const list = [...Hyprland.workspaces.values].filter(ws => ws && ws.id >= 1);
        // list.sort((a, b) => a.id - b.id);
        // const sig = list.map(w => String(w.id)).join(",");
        // if (sig !== _listSig) {
        //     _listSig = sig;
        //     _listCache = list;
        // }
        // return _listCache;
        return list;
    }

    Repeater {
        model: root.workspaceList

        delegate: BarBlock {
            id: rootBlock

            required property HyprlandWorkspace modelData

            readonly property HyprlandWorkspace ws: modelData

            readonly property bool isActive: ws?.active ?? false
            readonly property bool isUrgent: ws?.urgent ?? false
            readonly property bool hovered: mouseArea.containsMouse

            dim: false

            radius: height / 2

            border.width: isActive || isUrgent ? 1 : 0
            border.color: isUrgent ? "#ff5555" : Themes.activeHasClientsBorder

            color: isActive ? Qt.rgba(0.741, 0.576, 0.976, 0.18) : hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            // exact square for the focused workspace → perfect circle,
            // not an ellipse pill
            readonly property real diameter: content.implicitHeight + 7 // 8

            implicitHeight: diameter
            Layout.preferredWidth: isActive ? diameter : content.implicitWidth + 14
            Layout.preferredHeight: diameter

            onClicked: () => {
                if (ws)
                    HyprlandService.gotoWorkspace(ws.id);
            }

            // urgent workspaces pulse until visited
            SequentialAnimation on opacity {
                running: rootBlock.isUrgent && !rootBlock.isActive
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation {
                    to: 0.45
                    duration: 420
                }
                NumberAnimation {
                    to: 1
                    duration: 420
                }
            }

            content: BarText {
                text: String(rootBlock.ws?.id ?? "")
                color: rootBlock.isActive ? Themes.activeTextColor : rootBlock.isUrgent ? "#ff5555" : Qt.rgba(Themes.inactiveTextColor.r, Themes.inactiveTextColor.g, Themes.inactiveTextColor.b, rootBlock.hovered ? 0.95 : 0.55)
                dim: false
                font {
                    bold: rootBlock.isActive
                    // pixelSize: rootBlock.isActive ? 11 : 10
                    pixelSize: 10
                    family: "ZedMono Nerd Font"
                    // family: "fantasqueSansM Nerd Font"
                    // family: "lato"
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
        }
    }
}
