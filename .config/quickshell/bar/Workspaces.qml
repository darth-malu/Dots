import QtQuick
import qs.themes
import qs.customItems
import Quickshell.Hyprland
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell
import QtQuick.Effects

RowLayout {

    spacing: 3

    property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    Repeater {
        model: 
        model: ScriptModel {
            values: {
                var seenEmpty = false;
                return [...Hyprland.workspaces.values].filter(ws => {
                    if (ws.monitor !== monitor || ws.name.includes("special"))
                        return false;

                    // There is a flickering that can happen when switching from one
                    // empty workspace to another where both empty workspaces are shown
                    // on the bar at the same time.  This ensures that only the first
                    // empty workspace is shown.
                    const isNumeric = /^\d+$/.test(ws.name);
                    if (!isNumeric)
                        return true;
                    if (!seenEmpty) {
                        seenEmpty = true;
                        return true;
                    }
                    return false;
                });
                // Sort workspaces by id
                // .sort((a, b) => a.id - b.id);
            }
        }

        BarBlock {
            id: rootBlock

            property HyprlandWorkspace ws: modelData

            property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === ws.id

            property bool isOpen: monitor.activeWorkspace?.id === ws.id

            property bool hasClients: ws.name.length > 2

            property color workspaceBg: isActive ? (hasClients ? Themes.activeBg : "transparent") : Themes.inactiveBg

            property color borderColor: (isActive && hasClients) ? Themes.activeHasClientsBorder : "transparent"

            dim: false

            border.color: borderColor

            color: workspaceBg

            radius: height / 2

            gradient: (isActive || isOpen) && hasClients ? Themes.activeGradient : Themes.inactiveGradientV

            Layout.preferredWidth: content.width

            Layout.preferredHeight: content.height

            Rectangle {
                id: inactiveGradientH
                visible: !isActive && !isOpen
                gradient: Themes.inactiveGradientH
                implicitWidth: parent.width
                implicitHeight: parent.height
                radius: parent.radius
                z: -1
            }

            Rectangle {
                id: shadowThemes
                visible: Themes.borderShadow
                implicitWidth: parent.width - 1
                implicitHeight: parent.height - 1
                radius: parent.radius
                color: "indigo"
                border.color: parent.isActive || parent.isOpen ? "red" : "white" // Inner border color
                border.width: 1 // Inner border width
                x: 1
                y: 1
                z: -1
            }

            onClicked: function () {
                Hyprland.dispatch(`workspace ${ws.id}`);
            }

            content: RowLayout {
                spacing: 0
                anchors.centerIn: parent

                        Loader {
                            id: thetext
                            anchors.centerIn: parent
                            active: modelData.type === "text"
                            sourceComponent: BarText {
                                text: modelData.value
                                dim: !rootBlock.isActive
                                rightPadding: 5
                                color: dim ? Themes.inactiveTextColor : Themes.activeTextColor
                            }
                        }

                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
