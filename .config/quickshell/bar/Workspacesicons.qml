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

    // imperative refresh — bindings must never write their own dependencies,
    // or QML kills the loop and updates stall (the old binding-loop bug)
    function refresh() {
        var seenEmpty = false;
        const list = [...Hyprland.workspaces.values].filter(ws => {
            if (!ws || ws.monitor !== monitor || (ws.name ?? "").includes("special"))
                return false;
            const isNumeric = /^\d+$/.test(ws.name);
            if (!isNumeric)
                return true;
            // Only the first EMPTY numeric workspace is shown, so switching
            // between two empty workspaces never flashes two pills — but
            // populated workspaces must always survive this filter.
            const isEmpty = (ws.lastIpcObject?.windows ?? 0) === 0;
            if (isEmpty && seenEmpty)
                return false;
            if (isEmpty)
                seenEmpty = true;
            return true;
        });
        list.sort((a, b) => a.id - b.id);
        const sig = list.map(w => String(w.id)).join(",");
        if (sig !== _listSig) {
            _listSig = sig;
            _listCache = list;
            wsModel.values = list;
        }
        for (let i = 0; i < wsRepeater.count; i++) {
            const blk = wsRepeater.itemAt(i);
            if (blk?.applyIcons)
                blk.applyIcons();
        }
    }

    Timer {
        interval: 750
        running: root.visible
        repeat: true
        onTriggered: {
            root.wsRev++;
            root.refresh();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(ev) {
            const n = ev.name;
            if (n === "workspace" || n === "destroyworkspace" || n === "moveworkspace"
                || n === "movewindow" || n === "openwindow" || n === "closewindow" || n === "urgent") {
                root.wsRev++;
                root.refresh();
            }
        }
    }

    property string _listSig: ""
    property var _listCache: []

    Component.onCompleted: refresh()

    Repeater {
        id: wsRepeater

        model: ScriptModel {
            id: wsModel

            values: []
        }

        BarBlock {
            id: rootBlock

            required property var modelData
            property HyprlandWorkspace ws: modelData

            property bool isActive: (Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1) === (ws?.id ?? -2)

            // urgency lives in WorkspaceService (tracked from socket events)
            readonly property bool urgent: {
                const _rev = root.wsRev;
                return WorkspaceService.isUrgent(ws?.id ?? -1);
            }
            readonly property bool hovered: mouseArea.containsMouse

            // live app icons for this workspace — updated imperatively by
            // root.refresh(); identity stays stable so delegates never churn
            property var clientIcons: []

            function applyIcons() {
                const icons = WorkspaceService.clientIconsFor(ws, root.wsRev);
                const sig = icons.map(i => i.source + ":" + i.count).join("|");
                if (sig !== _iconSig) {
                    _iconSig = sig;
                    clientIcons = icons;
                }
            }

            Component.onCompleted: applyIcons()

            property string _iconSig: ""

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

            // slim pills — tight vertical fit everywhere, and the active
            // workspace gets the leanest horizontal padding so it reads as
            // a sleek highlight instead of a chunky container
            implicitHeight: content.implicitHeight + 4
            Layout.preferredWidth: content.implicitWidth + (isActive ? 8 : 12)
            Layout.preferredHeight: content.implicitHeight + 4

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

                spacing: 4

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
