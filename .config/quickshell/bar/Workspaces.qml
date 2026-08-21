pragma ComponentBehavior: Bound
import QtQuick
import qs.themes
import qs.customItems
import Quickshell.Hyprland
import QtQuick.Layouts
import Quickshell

RowLayout {
    spacing: 3
    Layout.rightMargin: 8

    property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    Repeater {
        model: ScriptModel {
            values: {
                return [...Hyprland.workspaces.values].filter(ws => {
                    if (ws.name.includes("special"))
                        return false;

                    return true;
                });
            }
        }

        delegate: BarBlock {
            id: rootBlock

            property HyprlandWorkspace ws: modelData

            property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === ws.id

            property bool isOpen: monitor.activeWorkspace?.id === ws.id

            property bool hasClients: ws.toplevels.values.length > 2

            property color workspaceBg: isActive ? (hasClients ? Themes.activeBg : "transparent") : Themes.inactiveBg

            property color borderColor: (isActive && hasClients) ? Themes.activeHasClientsBorder : "transparent"

            dim: false

            border.color: borderColor

            color: workspaceBg

            radius: height / 2

            Layout.preferredWidth: content.width
            Layout.preferredHeight: content.height

            onClicked: function () {
                ws.activate();
            }

            content: BarText {
                text: rootBlock.ws.id
                rightPadding: 5
                color: dim ? Themes.inactiveTextColor : Themes.activeTextColor
                font {
                    bold: false
                    // family: "lato"
                }
            }
        }
    }
}
