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

    spacing: 8
    // breathing room before the next module (active window)
    Layout.rightMargin: 14

    property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    // this screen's active workspace id — using focusedMonitor here (old
    // logic) left every non-focused monitor's bar without an active pill
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? -1

    // socket events bump the shared WorkspaceService revision + a short
    // poll keeps both the workspace list and its app icons fresh; the cache
    // keeps list identity stable between real changes so delegates don't churn
    readonly property int wsRev: WorkspaceService.revision

    // event-driven list refresh — the service's coalesced revision bump
    // replays here so workspace open/close still reflects immediately,
    // not just at poll ticks
    onWsRevChanged: root.refresh()

    // imperative refresh — bindings must never write their own dependencies,
    // or QML kills the loop and updates stall (the old binding-loop bug)
    //
    // CRITICAL: model writes are queued via Qt.callLater instead of running
    // inline. A synchronous `wsModel.values = …` inside onRawEvent/timer used
    // to incubate delegates while applyIcons() (fired from
    // Component.onCompleted mid-incubation) performed a NESTED setModel on
    // the inner icons Repeater — that re-entrancy segfaults Qt's delegate
    // model (VDMListDelegateDataType::createMissingProperties), killing
    // quickshell while it holds the popup input grab → frozen desktop.
    property bool _refreshQueued: false

    function refresh() {
        if (_refreshQueued)
            return; // coalesce bursts — one pass per event-loop cycle is enough
        _refreshQueued = true;
        Qt.callLater(() => {
            _refreshQueued = false;
            doRefresh();
        });
    }

    function doRefresh() {
        const activeId = root.activeWsId;
        const list = [...Hyprland.workspaces.values].filter(ws => {
            if (!ws || ws.monitor !== monitor || (ws.name ?? "").includes("special"))
                return false;
            if (!/^\d+$/.test(ws.name))
                return true; // named workspaces always shown
            // numeric empties pass through here and are collapsed to one
            // pill after the sort below — the ACTIVE empty workspace wins
            // that collapse (the old filter kept the first-seen empty, so
            // the pill for the workspace you were actually on could vanish
            // the moment a second empty existed)
            return true;
        });
        list.sort((a, b) => a.id - b.id);

        // empty-numeric collapse: keep exactly one — the active one if it is
        // empty, otherwise the lowest-numbered empty
        let result = list;
        const empties = list.filter(ws => /^\d+$/.test(ws.name) && (ws.lastIpcObject?.windows ?? 0) === 0 && ws.id !== activeId);
        if (empties.length > 1) {
            const drop = new Set(empties.slice(1).map(w => w.id));
            result = list.filter(ws => !drop.has(ws.id));
        }

        const sig = result.map(w => String(w.id)).join(",");
        // TEMP icondbg: per-ws toplevel counts vs displayed list
        // console.log(`[icondbg] doRefresh sig=${sig} rev=${root.wsRev} tls=[${result.map(w => (w.toplevels?.values.length ?? -1)).join(",")}]`);
        if (sig !== _listSig) {
            _listSig = sig;
            _listCache = result;
            wsModel.values = result;
        }
        // icon pass runs AFTER incubation settles — never nested inside the
        // model-change notification above
        Qt.callLater(() => {
            for (let i = 0; i < wsRepeater.count; i++) {
                const blk = wsRepeater.itemAt(i);
                if (blk?.applyIcons)
                    blk.applyIcons();
            }
        });
    }

    Timer {
        interval: 750
        running: root.visible
        repeat: true
        onTriggered: {
            // local re-read only — bumping the shared WorkspaceService
            // revision every tick made all bars' bindings churn forever
            root.refresh();
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

            property bool isActive: root.activeWsId === (ws?.id ?? -2)

            // urgency lives in WorkspaceService (tracked from socket events)
            readonly property bool urgent: {
                const _rev = root.wsRev;
                return WorkspaceService.isUrgent(ws?.id ?? -1);
            }
            readonly property bool hovered: mouseArea.containsMouse

            // live app icons for this workspace — updated imperatively by
            // root.refresh(); identity stays stable so delegates never churn
            property var clientIcons: []

            property bool _alive: true
            Component.onDestruction: _alive = false

            function applyIcons() {
                const icons = WorkspaceService.clientIconsFor(ws, root.wsRev);
                const sig = icons.map(i => i.source + ":" + i.count).join("|");
                if (sig !== _iconSig) {
                    _iconSig = sig;
                    // queued, never inline: assigning clientIcons swaps the
                    // inner Repeater's model, which must not happen while
                    // this delegate itself is mid-incubation
                    Qt.callLater(() => {
                        if (rootBlock._alive)
                            rootBlock.clientIcons = icons;
                    });
                }
            }

            Component.onCompleted: Qt.callLater(applyIcons)

            property string _iconSig: ""

            dim: false

            radius: height / 2

            border.width: isActive ? 1 : 0
            border.color: urgent ? "#ff5555" : Themes.activeHasClientsBorder

            color: isActive ? Qt.rgba(0.741, 0.576, 0.976, 0.18) : hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 120
                }
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
                NumberAnimation {
                    to: 0.45
                    duration: 420
                }
                NumberAnimation {
                    to: 1
                    duration: 420
                }
            }

            onClicked: function () {
                if (ws)
                    HyprlandService.gotoWorkspace(ws.id);
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
                            width: 14
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
                                    pixelSize: 9
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
