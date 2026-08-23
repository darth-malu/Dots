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
                // Full mode is edge-to-edge — no side margins at all
                right: BarState.barMode === 2 ? 0 : 10
                left: BarState.barMode === 2 ? 0 : 6
                top: 0
            }

            // Solid slab (mode 1): rounded, hairline border, side margins.
            // Full slab (mode 2): true full-bleed — square corners, no border.
            Rectangle {
                visible: BarState.barMode !== 0
                anchors.fill: parent
                radius: BarState.barMode === 2 ? 0 : 4
                color: "#181825"
                border.width: BarState.barMode === 2 ? 0 : 1
                border.color: "#313244"
                z: -1
            }

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

                    // workspace module — icons (default) or numbers, swappable live
                    Loader {
                        sourceComponent: MiscState.iconWorkspaces ? iconWorkspacesComp : numWorkspacesComp
                    }

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
                    SystemTray {
                        host: barr
                    }
                    ClockWidget {
                        host: barr
                    }
                    Battery {
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

            Component {
                id: iconWorkspacesComp

                Workspacesicons {}
            }

            Component {
                id: numWorkspacesComp

                Workspaces {}
            }
        }
    }
}
