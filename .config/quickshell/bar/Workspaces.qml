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

    Timer {
        interval: 750
        running: root.visible
        repeat: true
        onTriggered: WorkspaceService.refresh()
    }

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

            radius: boxy ? Themes.boxyRadius : height / 2

            border.width: boxy
                ? (isActive || isUrgent ? Themes.boxyBorderWidth : 0)
                : (isActive || isUrgent ? 1 : 0)
            border.color: isUrgent ? "#ff5555"
                : boxy ? Themes.boxyActiveBorder
                : Themes.activeHasClientsBorder

            color: boxy
                ? (isActive ? Themes.boxyActiveBg : "transparent")
                : (isActive ? Qt.rgba(0.741, 0.576, 0.976, 0.18)
                    : isUrgent ? Qt.rgba(1, 0.33, 0.33, 0.15)
                    : "transparent")

            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
            }
            Behavior on border.color {
                ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            // boxy active = perfect square, rounded active = perfect circle
            readonly property real sq: content.implicitHeight + 8

            implicitHeight: (boxy || (!boxy && isActive)) ? sq : content.implicitHeight + 4
            Layout.preferredWidth: isActive ? sq : content.implicitWidth + 14
            Layout.preferredHeight: (boxy || (!boxy && isActive)) ? sq : content.implicitHeight + 4

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
