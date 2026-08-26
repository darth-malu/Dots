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

    Timer {
        interval: 750
        running: root.visible
        repeat: true
        onTriggered: root.refresh()
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

            readonly property bool urgent: {
                const _rev = root.wsRev;
                return WorkspaceService.isUrgent(ws?.id ?? -1);
            }
            readonly property bool hovered: mouseArea.containsMouse

            property var clientIcons: []

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

            radius: boxy ? Themes.boxyRadius : height / 2

            border.width: boxy ? (isActive ? Themes.boxyBorderWidth : 0) : (isActive ? 1 : 0)
            border.color: urgent ? "#ff5555" : boxy ? Themes.boxyActiveBorder : Themes.activeHasClientsBorder

            color: boxy
                ? (isActive ? Themes.boxyActiveBg : "transparent")
                : (isActive ? Qt.rgba(0.741, 0.576, 0.976, 0.18) : "transparent")

            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
            }
            Behavior on border.color {
                ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            implicitHeight: content.implicitHeight + 4
            Layout.preferredWidth: content.implicitWidth + (isActive ? 8 : 12)
            Layout.preferredHeight: content.implicitHeight + 4

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            SequentialAnimation on opacity {
                running: rootBlock.urgent && !rootBlock.isActive
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 420 }
                NumberAnimation { to: 1; duration: 420 }
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
                    Layout.fillHeight: true
                    implicitWidth: boxy ? 20 : 18
                    radius: boxy ? Themes.boxyRadius : height / 2
                    color: rootBlock.isActive
                        ? (boxy ? Qt.rgba(0.74, 0.58, 0.98, 0.35) : Qt.rgba(0.741, 0.576, 0.976, 0.25))
                        : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(rootBlock.ws?.id ?? "")
                        color: rootBlock.isActive ? "#bd93f9" : (boxy ? Qt.rgba(0.74, 0.58, 0.98, 0.6) : Qt.rgba(1, 1, 1, 0.5))
                        font {
                            pixelSize: 9
                            bold: rootBlock.isActive
                            family: "ZedMono Nerd Font"
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
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                            }
                        }

                        Text {
                            visible: parent.count > 1
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: -2
                            anchors.bottomMargin: -3
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
