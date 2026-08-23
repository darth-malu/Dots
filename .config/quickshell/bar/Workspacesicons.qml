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
        model: ScriptModel {
            values: {
                var seenEmpty = false;
                return [...Hyprland.workspaces.values].filter(ws => {
                    if (ws.monitor !== monitor || ws.name.includes("special"))
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
            // underline: isActive ? true : false
            // underlineColor: "#D295BF"
            border.color: borderColor

            color: workspaceBg

            // layer.enabled: true

            radius: height / 2

            gradient: (isActive || isOpen) && hasClients ? Themes.activeGradient : Themes.inactiveGradientV

            Layout.preferredWidth: content.width

            Layout.preferredHeight: content.height

            // Behavior on border.color {
            //     ColorAnimation {
            //         duration: 120
            //     }
            // }

            // Behavior on color {
            //     ColorAnimation {
            //         duration: 100
            //     }
            // }

            // Behavior on gradient {
            //     ColorAnimation {
            //         duration: 100
            //     }
            // }

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

                Repeater {
                    id: therepeater
                    model: ScriptModel {
                        values: WorkspacesService.getChunks(ws.name)
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
                                    // TODO see if changes needed here
                                    visible: ws.mult > 1
                                    width: 10
                                    height: width
                                    radius: width / 2
                                    color: Themes.dropShadow
                                    opacity: 0.8
                                    BarText {
                                        text: ws.mult
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
