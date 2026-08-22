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
    property string diskIcon: ""
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

    onLeftClicked: allDisksPopup.visible = !allDisksPopup.visible
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
        color: MiscState.popupSolidBg ? "#282a36" : "transparent"

        anchor.window: disk.host
        anchor.rect.x: {
            let g = disk.mapToGlobal(0, 0);
            return g.x + (disk.width / 2) - (width / 2);
        }
        anchor.rect.y: {
            let g = disk.mapToGlobal(0, 0);
            return g.y + disk.height + 4;
        }

        implicitWidth: 420
        implicitHeight: allDisksCol.implicitHeight + 56

        Rectangle {
            anchors.fill: parent
            radius: 12
            layer.enabled: true
            layer.samples: 8
            color: "#282a36"
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
                anchors.margins: 14
                spacing: 7

                // header mirrors the data-row column widths below:
                // mount(140) · size(44) · free(44) · bar(fills) · use(32)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "mounts"
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
                    color: "#343746"
                }

                Repeater {
                    model: disk.allDisksList

                    RowLayout {
                        id: drow
                        required property string modelData
                        spacing: 6

                        readonly property var parts: modelData.trim().split(/\s+/)
                        readonly property int pct: parts.length >= 5 ? parseInt(parts[4]) || 0 : 0
                        readonly property color tier: pct > 90 ? "#ff5555" : pct > 75 ? "#ffb86c" : pct > 60 ? "#f1fa8c" : "#50fa7b"

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
                                color: drow.tier

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
                            color: drow.pct > 90 ? "#ff5555" : "#b8bfcb"
                            font {
                                pixelSize: 9
                                bold: drow.pct > 90
                                family: "ZedMono Nerd Font"
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