pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import Quickshell.Hyprland
import QtQuick.Layouts
import "./time"
import Quickshell.Wayland
import "./RHS"
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
            // OnDemand lets tray/quicksettings popups hold their grabs —
            // with None they get dismissed as soon as focus moves elsewhere
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
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

            // declared BEFORE panel so every module sits on top: wheels over
            // modules with their own handlers (mpris volume, pills, sliders)
            // are consumed there first; empty bar space falls through here
            // and steps workspaces
            MouseArea {
                acceptedButtons: Qt.NoButton
                anchors.fill: parent
                onWheel: wheel => {
                    // console.log(`[scrolldbg] bar wheel y=${wheel.angleDelta.y}`);
                    HyprlandService.stepWorkspace(wheel.angleDelta.y > 0);
                }
            }

            RowLayout {
                id: panel
                anchors.fill: parent

                RowLayout {
                    id: leftBlock
                    // spacing: 0.4
                    spacing: 10
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
                    // macOS menu-bar rhythm — one identical gap between modules
                    spacing: 8 // 14::

                    Resources {
                        host: barr
                    }
                    SystemTray {
                        host: barr
                        clockInside: true
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
