pragma ComponentBehavior: Bound
import QtQuick
import qs.themes
import qs.customItems
import Quickshell.Hyprland
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell
import qs.services

RowLayout {
    id: root

    spacing: 8
    Layout.rightMargin: 14

    property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? -1
    readonly property int wsRev: WorkspaceService.revision

    onWsRevChanged: root.refresh()

    property bool _refreshQueued: false

    function refresh() {
        if (_refreshQueued)
            return;
        _refreshQueued = true;
        Qt.callLater(() => {
            _refreshQueued = false;
            doRefresh();
        });
    }

    function doRefresh() {
        let list = [...Hyprland.workspaces.values].filter(ws => {
            if (!ws || ws.monitor !== monitor || (ws.name ?? "").includes("special"))
                return false;
            return true;
        });
        list.sort((a, b) => a.id - b.id);

        const sig = list.map(w => String(w.id)).join(",");
        if (sig !== _listSig) {
            _listSig = sig;
            _listCache = list;
            wsModel.values = list;
        }
        Qt.callLater(() => {
            for (let i = 0; i < wsRepeater.count; i++) {
                const blk = wsRepeater.itemAt(i);
                if (blk?.applyIcons)
                    blk.applyIcons();
            }
        });
    }

    // fully event-driven — WorkspaceService.refresh() fires on the IPC events
    // that change the icon set (open/close/move/title), and quickshell has
    // already applied each event to its native models by the time rawEvent
    // reaches QML, so the data read here is always settled

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

            readonly property bool urgent: ws?.urgent ?? false
            readonly property bool hovered: mouseArea.containsMouse

            property var clientIcons: []

            // empty = no client icons at all
            readonly property bool isEmpty: clientIcons.length === 0 && !isActive

            property bool _alive: true
            Component.onDestruction: _alive = false

            function applyIcons() {
                const icons = WorkspaceService.clientIconsFor(ws, root.wsRev);
                const sig = icons.map(i => i.source + ":" + i.count).join("|");
                if (sig !== _iconSig) {
                    _iconSig = sig;
                    Qt.callLater(() => {
                        if (rootBlock._alive)
                            rootBlock.clientIcons = icons;
                    });
                }
            }

            Component.onCompleted: Qt.callLater(applyIcons)

            property string _iconSig: ""

            dim: false

            readonly property bool boxy: MiscState.boxyTheme

            radius: boxy
                ? (isEmpty ? 0 : Themes.boxyRadius)
                : Themes.roundedRadius

            color: isEmpty ? "transparent"
                : boxy
                ? (isActive ? Themes.boxyActiveBg : "transparent")
                : (isActive ? Themes.roundedActiveBg : "transparent")

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            Layout.preferredWidth: content.implicitWidth
            Layout.preferredHeight: content.implicitHeight

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            onClicked: function () {
                if (ws)
                    HyprlandService.gotoWorkspace(ws.id);
            }

            content: RowLayout {
                id: iconRow

                spacing: 0

                // workspace number badge — visible in both themes
                Rectangle {
                    id: numberContainer
                    visible: !rootBlock.isEmpty || rootBlock.urgent
                    Layout.fillHeight: true
                    Layout.rightMargin: 4
                    implicitWidth: 18
                    implicitHeight: width
                    radius: boxy ? Themes.boxyRadius : Themes.roundedRadius
                    color: rootBlock.isActive
                        ? (boxy ? Themes.boxyActiveBg : Themes.roundedBadgeBg)
                        : rootBlock.urgent ? Themes.roundedUrgentBg
                        : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }

                    // urgent flash lives here — scoped to the badge, not the block
                    SequentialAnimation on opacity {
                        running: rootBlock.urgent && !rootBlock.isActive
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.45; duration: 420 }
                        NumberAnimation { to: 1; duration: 420 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(rootBlock.ws?.id ?? "")
                        color: rootBlock.isActive
                            ? Themes.accent
                            : rootBlock.urgent
                                ? "#ff5555"
                                : rootBlock.isEmpty
                                    ? Qt.rgba(1, 1, 1, 0.35)
                                    : (boxy ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.6) : Themes.roundedBadgeText)
                        font {
                            pixelSize: 12
                            bold: rootBlock.isActive
                            family: "Monofur Nerd Font"
                        }
                    }
                }

                Repeater {
                    model: rootBlock.clientIcons

                    delegate: Item {
                        id: iconCell

                        required property int index
                        required property var modelData

                        readonly property int count: modelData.count

                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 2
                        implicitWidth: 16
                        implicitHeight: 16

                        IconImage {
                            anchors.centerIn: parent
                            source: parent.modelData.source
                            implicitSize: 16
                            asynchronous: true
                            opacity: rootBlock.isActive ? 1 : 0.65

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Text {
                            visible: parent.count > 1
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            // anchors.rightMargin: -2
                            // anchors.bottomMargin: -3
                            text: parent.count
                            color: Themes.activeTextColor
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
