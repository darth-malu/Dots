pragma ComponentBehavior: Bound
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
    id: root

    spacing: 5
    // breathing room before the next module (active window)
    Layout.rightMargin: 12

    property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    // socket events + a short signature-checked poll keep both the
    // workspace list and its app icons fresh; the cache keeps list identity
    // stable between real changes so delegates don't churn
    property int wsRev: 0

    Timer {
        interval: 750
        running: root.visible
        repeat: true
        onTriggered: root.wsRev++
    }

    Connections {
        target: Hyprland

        function onRawEvent(ev) {
            const n = ev.name;
            if (n === "workspace" || n === "destroyworkspace" || n === "moveworkspace"
                || n === "openwindow" || n === "closewindow" || n === "urgent")
                root.wsRev++;
        }
    }

    property string _listSig: ""
    property var _listCache: []

    Repeater {
        model: ScriptModel {
            values: {
                const rev = root.wsRev; // dependency — rebuild on ws changes
                var seenEmpty = false;
                const list = [...Hyprland.workspaces.values].filter(ws => {
                    if (!ws || ws.monitor !== monitor || (ws.name ?? "").includes("special"))
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
                const sig = list.map(w => String(w.id)).join(",") 
                if (sig !== root._listSig) {
                    root._listSig = sig;
                    root._listCache = list;
                }
                return root._listCache;
            }
        }

        BarBlock {
            id: rootBlock

            required property var modelData
            property HyprlandWorkspace ws: modelData

            property bool isActive: (Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1) === (ws?.id ?? -2)

            readonly property bool urgent: ws?.urgent ?? false
            readonly property bool hovered: mouseArea.containsMouse

            // live app icons for this workspace — rebuilt whenever wsRev bumps
            readonly property var clientIcons: {
                const rev = root.wsRev; // dependency
                const icons = WorkspaceService.clientIconsFor(ws, rev);
                const sig = icons.map(i => i.source + ":" + i.count).join("|");
                if (sig !== rootBlock._iconSig) {
                    rootBlock._iconSig = sig;
                    rootBlock._iconCache = icons;
                }
                return rootBlock._iconCache;
            }

            property string _iconSig: ""
            property var _iconCache: []

            dim: false

            radius: height / 2

            border.width: isActive ? 1 : 0
            border.color: urgent ? "#ff5555" : Themes.activeHasClientsBorder

            color: isActive ? Qt.rgba(0.741, 0.576, 0.976, 0.18)
                : hovered ? Qt.rgba(1, 1, 1, 0.07)
                : "transparent"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 120 }
            }

            implicitHeight: content.implicitHeight + 8
            Layout.preferredWidth: content.implicitWidth + 16
            Layout.preferredHeight: content.implicitHeight + 8

            // urgent workspaces pulse until visited
            SequentialAnimation on opacity {
                running: rootBlock.urgent && !rootBlock.isActive
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 420 }
                NumberAnimation { to: 1; duration: 420 }
            }

            onClicked: function () {
                if (ws)
                    Hyprland.dispatch(`workspace ${ws.id}`);
            }

            content: RowLayout {
                id: iconRow

                spacing: 5

                BarText {
                    text: String(rootBlock.ws?.id ?? "")
                    pointSize: 10
                    dim: !rootBlock.isActive
                    color: rootBlock.isActive ? Themes.activeTextColor : Themes.inactiveTextColor
                    leftPadding: 0
                }

                Repeater {
                    model: rootBlock.clientIcons

                    delegate: Item {
                        id: iconCell

                        required property int index
                        required property var modelData

                        readonly property int count: modelData.count

                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 16
                        implicitHeight: 16

                        IconImage {
                            anchors.centerIn: parent
                            source: parent.modelData.source
                            implicitSize: 16
                            asynchronous: true
                            opacity: rootBlock.isActive ? 1 : 0.65

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowVerticalOffset: 1
                                shadowHorizontalOffset: 1
                                shadowBlur: 0.5
                                shadowColor: Themes.dropShadow
                                shadowOpacity: rootBlock.isActive ? 1 : 0.2
                            }
                        }

                        // multiplicity badge — N clients sharing this app class
                        Rectangle {
                            visible: parent.count > 1
                            width: 10
                            height: width
                            radius: width / 2
                            x: parent.width - width / 2 + 1
                            y: parent.height - height / 2 + 1
                            color: Themes.activeTextColor
                            border.width: 1
                            border.color: "#181825"

                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.count
                                color: "#181825"
                                font {
                                    pixelSize: 7
                                    bold: true
                                    family: "ZedMono Nerd Font"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
