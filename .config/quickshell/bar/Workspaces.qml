pragma ComponentBehavior: Bound
import QtQuick
import qs.themes
import qs.customItems
import Quickshell.Hyprland
import QtQuick.Layouts
import Quickshell

RowLayout {
    id: root

    spacing: 4
    Layout.rightMargin: 8

    // workspaces of every monitor, special slots filtered, numeric order —
    // sorted copy so ScriptModel gets a stable array
    readonly property var workspaceList: {
        const list = [...Hyprland.workspaces.values].filter(ws => ws && ws.id >= 1);
        list.sort((a, b) => a.id - b.id);
        return list;
    }

    Repeater {
        model: root.workspaceList

        delegate: BarBlock {
            id: rootBlock

            required property HyprlandWorkspace modelData

            readonly property HyprlandWorkspace ws: modelData

            // proper IPC bindables — `active` is per-monitor truth,
            // `focused` marks the workspace with keyboard focus
            readonly property bool isActive: ws?.active ?? false
            readonly property bool isFocused: ws?.focused ?? false
            readonly property bool isUrgent: ws?.urgent ?? false
            // window count straight from hyprctl's last json payload
            readonly property int clientCount: ws?.lastIpcObject?.windows ?? 0

            readonly property bool hovered: mouseArea.containsMouse

            dim: false

            radius: height / 2

            border.width: isActive ? 1 : 0
            border.color: isUrgent ? "#ff5555" : Themes.activeHasClientsBorder

            color: {
                if (isActive)
                    return Qt.rgba(0.741, 0.576, 0.976, 0.18);
                if (hovered)
                    return Qt.rgba(1, 1, 1, 0.07);
                return "transparent";
            }

            implicitHeight: content.implicitHeight + 8
            Layout.preferredWidth: content.implicitWidth + (isActive ? 16 : 10)
            Layout.preferredHeight: content.implicitHeight + 8

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutQuad
                }
            }

            onClicked: () => {
                if (ws)
                    ws.activate();
            }

            // urgent workspaces pulse until visited
            SequentialAnimation on opacity {
                running: rootBlock.isUrgent
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 420 }
                NumberAnimation { to: 1; duration: 420 }
            }

            content: BarText {
                text: String(rootBlock.ws?.id ?? "")
                color: {
                    if (rootBlock.isActive)
                        return Themes.activeTextColor;
                    return Qt.rgba(Themes.inactiveTextColor.r, Themes.inactiveTextColor.g, Themes.inactiveTextColor.b, rootBlock.hovered ? 0.9 : 0.55);
                }
                font {
                    bold: rootBlock.isActive
                    pixelSize: rootBlock.isActive ? 11 : 10
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }
        }
    }
}
