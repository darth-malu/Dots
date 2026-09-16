pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import Quickshell.Hyprland
import QtQuick.Layouts
import "./time"
import Quickshell.Wayland
import Quickshell.Widgets
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
            // WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand  //TODO: see if issue
            required property var modelData
            visible: root.enableBar

            // the screen from the screens list will be injected into this property
            // required property var modelData
            screen: modelData   // ALl currently connected screens, updates as connected screens change. Reusing a window on every screen This creates an instance of your window once on every screen. As screens are added or removed your window will be created or destroyed on those screens.

            aboveWindows: false
            color: 'transparent'
            implicitHeight: BarState.barHeight

            // bar treatments:
            // 0 Transparent, 1 Solid Margin, 3 Glass Margin keep side margins
            // → a non-zero barWidth shrinks/centers the bar slab on the screen.
            // 2 Solid, 4 Glass Full, 5 Glass Borderless run edge-to-edge and
            // ignore barWidth entirely.
            readonly property bool fullBleedMode: BarState.barMode === 2 || BarState.barMode === 4 || BarState.barMode === 5
            readonly property int centeredMargin: {
                if (BarState.barWidth <= 0)
                    return -1; // no slab → fall back to per-mode margins below
                const scrW = barr.screen?.width ?? 1920;
                return Math.max(0, Math.floor((scrW - Math.min(BarState.barWidth, scrW)) / 2));
            }

            margins {
                right: fullBleedMode ? 0 : (centeredMargin >= 0 ? centeredMargin : 10)
                left: fullBleedMode ? 0 : (centeredMargin >= 0 ? centeredMargin : 6)
                top: 0
            }

            // bar treatments:
            // 0 Transparent — no slab, side margins
            // 1 Solid Margin — solid slab, rounded, hairline border, margins
            // 2 Solid — true full-bleed solid, square, no border
            // 3 Glass Margin — translucent tinted slab, rounded, accent hairline
            // 4 Glass Full — edge-to-edge translucent, accent hairline
            // 5 Glass Borderless — edge-to-edge translucent, no border
            // glass modes rely on hyprland's blur rule (rules.lua, namespace
            // tildeBar) frosting whatever scrolls behind; alpha tuned for that
            Rectangle {
                visible: BarState.barMode !== 0
                anchors.fill: parent
                radius: BarState.barMode === 2 || BarState.barMode === 4 || BarState.barMode === 5 ? 0 : 4
                color: BarState.barMode === 3 || BarState.barMode === 4 || BarState.barMode === 5 ? Qt.rgba(Themes.barSolidBg.r, Themes.barSolidBg.g, Themes.barSolidBg.b, 0.45) : Themes.barSolidBg
                border.width: BarState.barMode === 3 || BarState.barMode === 4 ? 1 : (BarState.barMode >= 2 ? 0 : 1)
                border.color: BarState.barMode === 3 || BarState.barMode === 4 ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.28) : Themes.borderColor
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
                    spacing: MiscState.showWorkspaces ? 10 : 0
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: 6

                    // workspace module — icons (default) or numbers, swappable live.
                    // width collapses to 0 when disabled so the bar space is
                    // actually reclaimed and handed back to the ActiveWindow title
                    Loader {
                        visible: MiscState.showWorkspaces
                        width: MiscState.showWorkspaces ? implicitWidth : 0
                        sourceComponent: MiscState.iconWorkspaces ? iconWorkspacesComp : numWorkspacesComp
                    }
                }

                MouseArea {
                    id: barActions

                    implicitHeight: BarState.barHeight
                    Layout.fillWidth: true
                    Layout.leftMargin: 20

                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    // anchors.fill: parent
                    onWheel: wheel => {
                        // console.log(`[scrolldbg] bar wheel y=${wheel.angleDelta.y}`);
                        HyprlandService.stepWorkspace(wheel.angleDelta.y > 0);
                    }
                    onClicked: mouse => {
                        const gx = barActions.mapToGlobal(mouse.x, 0).x;
                        styleMenu.openAt(mouse.button === Qt.RightButton ? 0 : 1, gx);
                    }
                    ActiveWindow {
                        id: activeText
                    }
                }

                RowLayout {
                    id: rightBlock
                    Layout.alignment: Qt.AlignRight
                    // macOS menu-bar rhythm — one identical gap between modules
                    spacing: Themes.moduleGap

                    // media moves in-line with the right cluster so the centered
                    // pill can no longer slide under the active-window title

                    Mpris {
                        host: barr
                        Layout.rightMargin: 3
                    }

                    Resources {
                        host: barr
                    }
                    Git {
                        // visible: false
                        visible: MiscState.showGit
                        host: barr
                    }
                    SystemTray {
                        host: barr
                        clockInside: true
                    }
                }
            }

            BrightnessOsd {
                barWindow: barr
            }

            StyleMenu {
                id: styleMenu
                host: barr
            }

            Component {
                id: iconWorkspacesComp

                WorkspaceIcons {}
            }

            Component {
                id: numWorkspacesComp

                WorkspaceNumbers {}
            }
        }
    }
}
