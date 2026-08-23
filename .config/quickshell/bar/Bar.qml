pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import Quickshell.Hyprland
import QtQuick.Layouts
import "./time"
import Quickshell.Wayland
import "./systemTray"
import qs.themes
import qs.services
import qs.customItems

ShellRoot {
    id: root

    readonly property bool enableBar: BarState.enableBar

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barr
            WlrLayershell.namespace: "tildeBar"
            required property var modelData
            visible: root.enableBar

            // the screen from the screens list will be injected into this property
            // required property var modelData
            screen: modelData   // ALl currently connected screens, updates as connected screens change. Reusing a window on every screen This creates an instance of your window once on every screen. As screens are added or removed your window will be created or destroyed on those screens.

            aboveWindows: false
            color: 'transparent'
            implicitHeight: 26

            margins {
                right: 10
                left: 6
                // transparent setup sits flush with the top edge
                top: BarState.solidBar ? 2 : 0
            }

            // Solid (non-transparent) background — full slab, radius 4,
            // hanging 2px off the top edge so it reads as a crisp panel
            Rectangle {
                visible: BarState.solidBar
                anchors.fill: parent
                radius: 4
                color: "#181825"
                border.width: 1
                border.color: "#313244"
                z: -1
            }

            // Transparent setup — no background at all, modules float on the
            // wallpaper; bar sits flush with the top edge (no top margin)

            anchors {
                top: true
                left: true
                right: true
            }

            RowLayout {
                id: panel
                anchors.fill: parent

                RowLayout {
                    id: leftBlock
                    spacing: 0.4
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: 6

                    // Workspacesicons {}
                    // Workspaces {} //FIXME: Hyprland Workspaces seem not to be working
                    ActiveWindow {}
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 50
                }

                RowLayout {
                    id: rightBlock
                    Layout.alignment: Qt.AlignRight
                    spacing: 7

                    Resources {
                        host: barr
                    }
                    ClockWidget {
                        host: barr
                    }
                    Battery {
                        host: barr
                    }
                    SystemTray {
                        host: barr
                    }
                }
            }

            MouseArea {
                id: nullspaceMA
                acceptedButtons: Qt.NoButton
                anchors.fill: parent
                onWheel: wheel => {
                    var pos = mapToItem(rightBlock, wheel.x, wheel.y);
                    if (rightBlock.contains(Qt.point(pos.x, pos.y))) {
                        wheel.accepted = false;
                        return;
                    }

                    if (wheel.angleDelta.y > 0) {
                        Hyprland.dispatch('workspace "m-1"');
                    } else if (wheel.angleDelta.y < 0) {
                        Hyprland.dispatch('workspace "m+1"');
                    }
                }
            }

            Mpris {
                host: barr
                anchors.centerIn: parent
            }

            BrightnessOsd {
                barWindow: barr
            }
        }
    }
}
