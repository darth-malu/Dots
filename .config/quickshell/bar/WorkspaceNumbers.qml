pragma ComponentBehavior: Bound
import QtQuick
import qs.themes
import qs.customItems
import qs.services
import Quickshell.Hyprland
import QtQuick.Layouts

RowLayout {
    id: root

    spacing: 4

    readonly property int wsRev: WorkspaceService.revision

    readonly property var workspaceList: {
        const rev = wsRev;
        // quickshell 0.3.1 no longer reports numeric workspace ids (Hyprland
        // 0.56 goes by name) — id comes back 0/-1. Filter + sort on name.
        const list = [...Hyprland.workspaces.values].filter(ws => ws && !(ws.name ?? "").includes("special"));
        list.sort((a, b) => String(a.name ?? 0).localeCompare(String(b.name ?? 0), undefined, { numeric: true }));
        return list;
    }

    Repeater {
        model: root.workspaceList

        delegate: BarBlock {
            id: rootBlock

            required property var modelData

            readonly property var ws: modelData
            readonly property bool isActive: ws?.active ?? false
            readonly property bool isUrgent: ws?.urgent ?? false
            readonly property bool hovered: mouseArea.containsMouse

            dim: false

            readonly property bool boxy: MiscState.boxyTheme

            // empty workspaces get a subtle accent tint so every workspace
            // reads as a pill — no more floating transparent numbers
            readonly property bool isEmpty: !isActive && !isUrgent

            radius: boxy ? Themes.boxyRadius : Themes.roundedRadius

            border.width: boxy ? Themes.boxyBorderWidth : Themes.roundedBorderWidth
            border.color: isUrgent ? "#ff5555"
                : boxy ? Themes.boxyActiveBorder
                : Themes.roundedActiveBorder

            color: isEmpty ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.1)
                : boxy
                ? (isActive ? Themes.boxyActiveBg : "transparent")
                : (isActive ? Themes.roundedActiveBg
                    : isUrgent ? Themes.roundedUrgentBg
                    : "transparent")

            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
            }
            Behavior on border.color {
                ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            // boxy active = perfect square, rounded active = perfect circle
            readonly property int pillSize: content.implicitHeight + 8

            implicitHeight: pillSize
            Layout.preferredWidth: isActive || (!boxy && !isEmpty) ? pillSize : content.implicitWidth + 14
            Layout.preferredHeight: pillSize

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }
            Behavior on implicitHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            onClicked: () => {
                if (ws)
                    HyprlandService.gotoWorkspace(ws.name);
            }

            SequentialAnimation on opacity {
                running: rootBlock.isUrgent && !rootBlock.isActive
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 420 }
                NumberAnimation { to: 1; duration: 420 }
            }

            content: BarText {
                text: String(rootBlock.ws?.name ?? "")
                color: rootBlock.isActive
                    ? Themes.activeTextColor
                    : rootBlock.isUrgent ? "#ff5555"
                    : rootBlock.isEmpty ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.75)
                    : Themes.barMuted
                dim: false
                font {
                    bold: rootBlock.isActive
                    pixelSize: 10
                    family: "ZedMono Nerd Font"
                }

                Behavior on color {
                    ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
