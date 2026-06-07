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
    property string diskIcon: ""
    property string diskLabel: ""
    property bool showPercent: false
    property bool showUsage: false

    property color colorLow: "#a6e3a1"
    property color colorMid: "#f5c2e7"
    property color colorHigh: "#89dceb"
    property color colorDanger: "#f38ba8"
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

    onLeftClicked: showUsage = !showUsage
    onRightClicked: showPercent = !showPercent
    onMiddleClicked: allDisksPopup.visible = !allDisksPopup.visible

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
            id: percentText
            visible: disk.showPercent
            symbolText: `${disk.diskUsageValue}%`
            baseColor: disk.diskColor
            pointSize: 11
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
        color: 'transparent'

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
        implicitHeight: Math.min(allDisksCol.implicitHeight + 38, 400)

        Rectangle {
            anchors.fill: parent
            radius: 10
            layer.enabled: true
            layer.samples: 8
            color: "#1e1e2e"
            border.color: "#45475a"

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 34
                radius: 10
                color: Qt.rgba(0.49, 0.73, 0.44, 0.06)

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 14
                    }
                    text: "  All Mounts"
                    color: Themes.mprisTextColor
                    font {
                        pixelSize: 12
                        bold: true
                        family: "Quicksand"
                    }
                }

                Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 14
                    }
                    text: "size  free   %"
                    color: Themes.mprisVolumeColor
                    font {
                        pixelSize: 9
                        family: "ZedMono Nerd Font"
                        letterSpacing: 1
                    }
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    topMargin: 34
                    left: parent.left
                    leftMargin: 14
                    right: parent.right
                    rightMargin: 14
                }
                height: 1
                color: "#313244"
            }

            Flickable {
                anchors {
                    top: parent.top
                    topMargin: 42
                    left: parent.left
                    leftMargin: 14
                    right: parent.right
                    rightMargin: 14
                    bottom: parent.bottom
                    bottomMargin: 10
                }
                contentHeight: allDisksCol.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: allDisksCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: disk.allDisksList

                        RowLayout {
                            required property string modelData
                            spacing: 6

                            readonly property var parts: modelData.trim().split(/\s+/)
                            readonly property int pct: parts.length >= 5 ? parseInt(parts[4]) || 0 : 0

                            Text {
                                Layout.preferredWidth: 140
                                text: parent.parts[0] || ""
                                color: Themes.mprisTextColor
                                font {
                                    pixelSize: 10
                                    family: "ZedMono Nerd Font"
                                }
                                elide: Text.ElideRight
                                clip: true
                            }

                            Text {
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignRight
                                text: parent.parts[1] || ""
                                color: "#585b70"
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                            }

                            Text {
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignRight
                                text: parent.parts[3] || ""
                                color: "#a6adc8"
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 8
                                radius: 4
                                color: "#313244"

                                Rectangle {
                                    width: parent.width * Math.min(parent.parent.pct / 100, 1)
                                    height: parent.height
                                    radius: 4
                                    color: parent.parent.pct > 90 ? "#f38ba8" : parent.parent.pct > 70 ? "#f9e2af" : Themes.toxicGreen

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
                                text: `${parent.pct}%`
                                color: parent.parent.pct > 90 ? "#f38ba8" : "#a6adc8"
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                    bold: parent.pct > 90
                                }
                            }
                        }
                    }

                    Text {
                        text: "No mounts found"
                        color: "#585b70"
                        font {
                            pixelSize: 10
                            family: "ZedMono Nerd Font"
                        }
                        visible: disk.allDisksList.length === 0
                    }
                }
            }
        }
    }
}
