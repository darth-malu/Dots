import QtQuick
import qs.themes
import qs.customItems
import Quickshell.Hyprland
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell
import QtQuick.Effects
import qs.services

RowLayout {
    spacing: 3
    property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    Repeater {
        model: ScriptModel {
            values: {
                var seenEmpty = false;
                const list = [...Hyprland.workspaces.values].filter(ws => {
                    if (!ws || ws.monitor !== monitor || ws.name.includes("special"))
                        return false;
                    // There is a flickering that can happen when switching from one empty workspace to another where both empty workspaces are shown
                    // on the bar at the same time.  This ensures that only the first empty workspace is shown.
                    const isNumeric = /^\d+$/.test(ws.name);
                    if (!isNumeric)
                        return true;
                    if (!seenEmpty) {
                        seenEmpty = true;
                        return true;
                    }
                    return false;
                });
                list.sort((a, b) => a.id - b.id);
                return list;
            }
        }

        BarBlock {
            id: rootBlock

            required property var modelData
            property HyprlandWorkspace ws: modelData

            property bool isActive: (Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1) === (ws?.id ?? -2)

            property bool isOpen: monitor.activeWorkspace?.id === ws.id

            // real client count instead of the old name-length heuristic
            property bool hasClients: (ws?.lastIpcObject?.windows ?? 0) > 0

            readonly property bool hovered: mouseArea.containsMouse

            dim: false

            radius: height / 2

            border.width: isActive ? 1 : 0
            border.color: Themes.activeHasClientsBorder

            color: isActive ? Qt.rgba(0.741, 0.576, 0.976, 0.18)
                : hovered ? Qt.rgba(1, 1, 1, 0.07)
                : "transparent"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            onClicked: function () {
                if (ws)
                    Hyprland.dispatch(`workspace ${ws.id}`);
            }

            content: RowLayout {
                spacing: 0
                anchors.centerIn: parent

                Repeater {
                    id: therepeater
                    model: ScriptModel {
                        values: WorkspaceService.getChunks(ws?.name ?? "")
                    }

                    delegate: Item {
                        property bool showText: modelData.type === "text"
                        property bool showIcon: modelData.type === "icon"
                        property int symbolSize: 18 // 18
                        property int spacerSize: 3

                        implicitWidth: {
                            if (showText)
                                return thetext.implicitWidth;
                            if (showIcon)
                                return symbolSize;
                            return spacerSize;
                        }
                        implicitHeight: {
                            if (showText)
                                return thetext.implicitHeight;
                            if (showIcon)
                                return symbolSize;
                            return spacerSize;
                        }
                        Layout.alignment: Qt.AlignCenter

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

                        Loader {
                            id: theicon
                            anchors.centerIn: parent
                            active: modelData.type === "icon"
                            sourceComponent: Item {
                                implicitWidth: inside.implicitWidth
                                implicitHeight: inside.implicitHeight
                                IconImage {
                                    id: inside
                                    // anchors.centerIn: parent
                                    source: modelData.source
                                    implicitSize: symbolSize
                                    opacity: ws.active ? 1 : 0.7
                                    // mipmap: true
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowVerticalOffset: 1
                                        shadowHorizontalOffset: 1
                                        shadowBlur: 0.5
                                        shadowColor: Themes.dropShadow
                                        shadowOpacity: ws.active ? 1 : 0.2
                                    }
                                }
                                Rectangle {
                                    // multiplicity badge — same icon seen N times
                                    // in this workspace name
                                    visible: modelData.mult > 1
                                    width: 10
                                    height: width
                                    radius: width / 2
                                    color: Themes.dropShadow
                                    opacity: 0.8
                                    BarText {
                                        text: modelData.mult
                                        pointSize: 11
                                        dim: !rootBlock.isActive
                                        style: Text.Outline
                                        styleColor: "black"
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
