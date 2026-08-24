import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.themes

BarBlock {
    id: disk
    underline: false

    required property var host

    property string mountPoint: "/"
    property string diskIcon: "\uf0a0"
    property string diskLabel: ""
    property bool showUsage: false

    property color colorLow: "#50fa7b"
    property color colorMid: "#ff79c6"
    property color colorHigh: "#8be9fd"
    property color colorDanger: "#ff5555"
    property int dangerThreshold: 90

    readonly property int diskUsageValue: ResourcesState.diskUsagePercent
    readonly property string diskFigures: `${ResourcesState.diskUsed}/${ResourcesState.diskTotal}`

    readonly property color diskColor: {
        const v = diskUsageValue;
        if (v >= dangerThreshold)
            return colorDanger;
        if (v >= 60)
            return colorHigh;
        if (v >= 30)
            return colorMid;
        return colorLow;
    }

    readonly property var allDisksList: {
        var raw = ResourcesState.allDisks.trim();
        return raw.length > 0 ? raw.split("\n") : [];
    }

    onLeftClicked: {
        allDisksPopup.visible = !allDisksPopup.visible;
        if (NasState.available)
            NasState.kickRecheck(1);
    }
    onRightClicked: showUsage = !showUsage

    content: RowLayout {
        spacing: 4

        Canvas {
            id: gauge

            readonly property real progress: Math.min(disk.diskUsageValue / 100, 1)

            implicitWidth: 22
            implicitHeight: 22

            onProgressChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var cx = width / 2;
                var cy = height / 2;
                var r = cx - 2;
                var lw = 3;
                var startAngle = -Math.PI / 2;

                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.strokeStyle = "rgba(255, 255, 255, 0.06)";
                ctx.lineWidth = lw;
                ctx.stroke();

                if (progress > 0) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, startAngle, startAngle + Math.PI * 2 * Math.min(progress, 0.999));
                    ctx.strokeStyle = disk.diskColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }

                ctx.fillStyle = disk.diskColor;
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.font = `11px "Symbols Nerd Font Mono"`;
                ctx.fillText(disk.diskIcon, cx, cy + 0.5);
            }
        }

        BarText {
            id: usageText
            visible: disk.showUsage
            symbolText: disk.diskLabel.length > 0 ? disk.diskLabel : disk.diskFigures
            baseColor: disk.diskColor
            pointSize: 11
        }
    }

    PopupWindow {
        id: allDisksPopup
        visible: false
        grabFocus: true
        color: "transparent"

        anchor.window: disk.host
        anchor.rect.x: {
            let g = disk.mapToGlobal(0, 0);
            return g.x + (disk.width / 2) - (width / 2);
        }
        anchor.rect.y: 33

        implicitWidth: 420
        implicitHeight: allDisksCol.implicitHeight + 24

        Rectangle {
            anchors.fill: parent
            radius: 12
            layer.enabled: true
            layer.samples: 8
            color: MiscState.popupCardBg
            border.width: 1
            border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

            Shortcut {
                sequence: "Escape"
                onActivated: allDisksPopup.visible = false
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: allDisksPopup.visible = false
            }

            ColumnLayout {
                id: allDisksCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 0

                // ── NAS zone — per-share mount controls + unmounted tally ──
                ColumnLayout {
                    visible: NasState.available
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "\uf4a6"
                            color: NasState.allMounted ? "#50fa7b" : "#ffb86c"
                            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
                        }

                        Text {
                            text: "NAS"
                            color: "#f8f8f2"
                            font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 1 }
                        }

                        Text {
                            readonly property int missing: NasState.unmountedCount
                            text: missing === 0 ? "all mounted" : `${missing} unmounted`
                            color: missing === 0 ? "#50fa7b" : "#ffb86c"
                            font { pixelSize: 9; bold: true; family: "Quicksand" }
                        }

                        Item { Layout.fillWidth: true }

                        // one-click remount of every missing share
                        Rectangle {
                            visible: NasState.unmountedCount > 0
                            implicitWidth: mountAllTxt.implicitWidth + 14
                            implicitHeight: 18
                            radius: 9
                            color: mountAllMa.containsMouse ? Qt.rgba(0.31, 0.98, 0.48, 0.15) : "#343746"

                            Text {
                                id: mountAllTxt
                                anchors.centerIn: parent
                                text: "\ueb5b  mount all"
                                color: mountAllMa.containsMouse ? "#50fa7b" : "#b8bfcb"
                                font { pixelSize: 9; bold: true; family: "Symbols Nerd Font Mono, Quicksand" }
                            }

                            MouseArea {
                                id: mountAllMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NasState.mountAll()
                            }
                        }
                    }

                    Repeater {
                        model: NasState.shares

                        Rectangle {
                            id: nasRow

                            required property var modelData

                            readonly property bool mounted: NasState.isMounted(nasRow.modelData)

                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 6
                            color: nasRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"

                            MouseArea {
                                id: nasRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 8

                                // live status dot
                                Rectangle {
                                    implicitWidth: 7
                                    implicitHeight: 7
                                    radius: 3.5
                                    color: nasRow.mounted ? "#50fa7b" : "#ff5555"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: nasRow.modelData.name
                                    color: "#f8f8f2"
                                    font { pixelSize: 10; bold: true; family: "Quicksand" }
                                }

                                // mount / unmount action chip — fixed width so
                                // mount and unmount occupy identical footprints
                                Rectangle {
                                    implicitWidth: 78
                                    implicitHeight: 20
                                    radius: 9
                                    color: {
                                        if (!nasBtnMouse.containsMouse)
                                            return nasRow.mounted ? "transparent" : "#343746";
                                        return nasRow.mounted ? Qt.rgba(1, 0.33, 0.33, 0.15) : Qt.rgba(0.31, 0.98, 0.48, 0.15);
                                    }
                                    border.width: nasRow.mounted && !nasBtnMouse.containsMouse ? 1 : 0
                                    border.color: Qt.rgba(1, 1, 1, 0.12)

                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    Text {
                                        id: nasActionTxt
                                        anchors.centerIn: parent
                                        text: nasRow.mounted ? "\uf07c unmount" : "\ueb5b mount"
                                        color: {
                                            if (!nasBtnMouse.containsMouse)
                                                return nasRow.mounted ? "#b8bfcb" : "#50fa7b";
                                            return nasRow.mounted ? "#ff5555" : "#50fa7b";
                                        }
                                        font { pixelSize: 9; bold: true; family: "Symbols Nerd Font Mono, Quicksand" }
                                    }

                                    MouseArea {
                                        id: nasBtnMouse
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: nasRow.mounted ? NasState.unmount(nasRow.modelData) : NasState.mount(nasRow.modelData)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                    }
                }

                // ── data zone — flat table straight on the popup, no recessed panel ──
                ColumnLayout {
                    id: mountZone
                    Layout.fillWidth: true
                    spacing: 4

                        // column labels — widths mirror the rows below:
                        // mount(140) · size(44) · free(44) · bar(fills) · use(32)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "mount"
                                color: "#6272a4"
                                font {
                                    pixelSize: 9
                                    bold: true
                                    family: "Quicksand"
                                    letterSpacing: 1
                                }
                                Layout.preferredWidth: 140
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "size"
                                color: "#6272a4"
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                                Layout.preferredWidth: 44
                                Layout.alignment: Qt.AlignRight
                            }

                            Text {
                                text: "free"
                                color: "#6272a4"
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                                Layout.preferredWidth: 44
                                Layout.alignment: Qt.AlignRight
                            }

                            // spacer standing in for the usage-bar column
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                            }

                            Text {
                                text: "use"
                                color: "#6272a4"
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                                Layout.preferredWidth: 32
                                Layout.alignment: Qt.AlignRight
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        Repeater {
                            model: disk.allDisksList

                            Rectangle {
                                id: drow

                                required property string modelData

                                readonly property var parts: modelData.trim().split(/\s+/)
                                readonly property int pct: parts.length >= 5 ? parseInt(parts[4]) || 0 : 0
                                // cpu-popup band palette for consistency
                                readonly property color tier: pct > 90 ? "#ff5555"
                                    : pct > 75 ? "#ffb86c"
                                    : pct > 60 ? "#50fa7b"
                                    : "#8be9fd"

                                Layout.fillWidth: true
                                implicitHeight: 22
                                radius: 6
                                color: dmouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"

                                MouseArea {
                                    id: dmouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 6

                                    Text {
                                        Layout.preferredWidth: 140
                                        text: drow.parts[0] || ""
                                        color: "#f8f8f2"
                                        font {
                                            pixelSize: 10
                                            family: "ZedMono Nerd Font"
                                        }
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        Layout.preferredWidth: 44
                                        horizontalAlignment: Text.AlignRight
                                        text: drow.parts[1] || ""
                                        color: "#6272a4"
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 44
                                        horizontalAlignment: Text.AlignRight
                                        text: drow.parts[3] || ""
                                        color: "#b8bfcb"
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 5
                                        radius: 2.5
                                        color: Qt.rgba(1, 1, 1, 0.06)

                                        Rectangle {
                                            width: parent.width * Math.min(drow.pct / 100, 1)
                                            height: parent.height
                                            radius: 2.5
                                            color: Qt.rgba(drow.tier.r, drow.tier.g, drow.tier.b, 0.55)

                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 2
                                                radius: 1
                                                height: parent.height + 2
                                                visible: drow.pct > 3
                                                color: drow.tier
                                            }

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 32
                                        horizontalAlignment: Text.AlignRight
                                        text: `${drow.pct}%`
                                        color: drow.tier
                                        font {
                                            pixelSize: 9
                                            bold: true
                                            family: "ZedMono Nerd Font"
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "no mounts found"
                            color: "#6272a4"
                            font {
                                pixelSize: 10
                                italic: true
                                family: "Quicksand"
                            }
                            visible: disk.allDisksList.length === 0
                            Layout.alignment: Qt.AlignHCenter
                        }
                }
            }
        }
    }
}