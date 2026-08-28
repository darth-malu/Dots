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
        const list = [...Hyprland.workspaces.values].filter(ws => ws && ws.id >= 1);
        list.sort((a, b) => a.id - b.id);
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

            // empty workspaces: no bg, no border — just the bare number
            readonly property bool isEmpty: !isActive && !isUrgent

            radius: boxy
                ? (isEmpty ? 0 : Themes.boxyRadius)
                : Themes.roundedRadius

            border.width: isEmpty ? 0 : (boxy
                ? (Themes.boxyBorderWidth)
                : Themes.roundedBorderWidth)
            border.color: isUrgent ? "#ff5555"
                : boxy ? Themes.boxyActiveBorder
                : Themes.roundedActiveBorder

            color: isEmpty ? "transparent"
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
                    HyprlandService.gotoWorkspace(ws.id);
            }

            SequentialAnimation on opacity {
                running: rootBlock.isUrgent && !rootBlock.isActive
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 420 }
                NumberAnimation { to: 1; duration: 420 }
            }

            content: BarText {
                text: String(rootBlock.ws?.id ?? "")
                color: rootBlock.isActive
                    ? Themes.activeTextColor
                    : rootBlock.isUrgent ? "#ff5555"
                    : rootBlock.isEmpty ? Qt.rgba(1, 1, 1, 0.35)
                    : Themes.inactiveTextColor
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
