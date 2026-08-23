import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.customItems

BarBlock {
    id: cpu
    border.width: 0

    required property var host

    // inline % readout beside the gauge · toggled by right-click
    property bool showUsage: true

    readonly property int cpuPercent: ResourcesState.cpuUsageString
    readonly property real cpuTemp: ResourcesState.cpuTemp

    // session temperature extremes (since shell start)
    property real tempMin: cpuTemp
    property real tempMax: cpuTemp
    onCpuTempChanged: {
        if (cpuTemp > 0) {
            if (tempMin <= 0 || cpuTemp < tempMin)
                tempMin = cpuTemp;
            if (cpuTemp > tempMax)
                tempMax = cpuTemp;
        }
    }

    readonly property color cpuColor: cpuPercent > 80 ? "#ff5555" : cpuPercent > 60 ? "#f1fa8c" : "#bd93f9"

    function tempColor(t) {
        if (t >= 75)
            return "#ff5555";
        if (t >= 62)
            return "#ffb86c";
        if (t >= 45)
            return "#f1fa8c";
        return "#8be9fd";
    }

    // left-click opens the per-process popup · right-click toggles the
    // inline usage readout beside the gauge
    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            MiscState.showCpuProcs = !MiscState.showCpuProcs;
    }

    onRightClicked: mouse => {
        cpu.showUsage = !cpu.showUsage;
    }

    content: RowLayout {
        spacing: 4

        Canvas {
            id: gauge

            readonly property real progress: cpu.cpuPercent / 100

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
                    ctx.strokeStyle = cpu.cpuColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }

                ctx.fillStyle = cpu.cpuColor;
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.font = `11px "Symbols Nerd Font Mono"`;
                ctx.fillText("", cx, cy + 0.5);
            }
        }

        // live usage readout beside the gauge ring
        BarText {
            id: usageText
            visible: cpu.showUsage
            symbolText: `${cpu.cpuPercent}%`
            baseColor: cpu.cpuColor
            pointSize: 11
        }
    }

    Process {
        id: procsProc
        // aggregate cpu usage + real memory footprint (RSS) by process name
        command: ["sh", "-c", "ps -eo pcpu,rss,comm --no-headers | awk '{c=$1; r=$2; $1=$2=\"\"; sub(/^ +/, \"\"); k=$0; cc[k]+=c; rr[k]+=r; cnt[k]++} END {for (k in cc) printf \"%.1f %d %d %s\\n\", cc[k], rr[k], cnt[k], k}' | sort -rn | head -10"]
        property string buf: ""
        running: false

        stdout: SplitParser {
            onRead: data => procsProc.buf += data + "\n"
        }

        onExited: {
            const rows = [];
            for (const line of procsProc.buf.trim().split("\n")) {
                const p = line.trim().split(/\s+/);
                if (p.length >= 4)
                    rows.push({
                        c: parseFloat(p[0]) || 0,
                        kib: parseInt(p[1]) || 0,
                        n: parseInt(p[2]) || 1,
                        name: p.slice(3).join(" ")
                    });
            }
            // update rows in place — reassigning a plain array model would tear
            // down and recreate every delegate each tick (popup flicker)
            while (procModel.count > rows.length)
                procModel.remove(procModel.count - 1);
            for (let i = 0; i < rows.length; i++) {
                if (i < procModel.count)
                    procModel.set(i, rows[i]);
                else
                    procModel.append(rows[i]);
            }
            procsProc.buf = "";
        }
    }

    ListModel {
        id: procModel
    }

    Timer {
        interval: 2000
        running: MiscState.showCpuProcs
        repeat: true
        triggeredOnStart: true
        onTriggered: procsProc.running = true
    }

    LazyLoader {
        loading: true

        PopupWindow {
            id: procPopup
            visible: MiscState.showCpuProcs
            grabFocus: true
            color: "transparent"

            anchor.window: cpu.host
            anchor.rect.x: {
                let g = cpu.mapToGlobal(0, 0);
                return g.x + (cpu.width / 2) - (width / 2);
            }
            anchor.rect.y: 33

            implicitWidth: 300
            implicitHeight: procCol.implicitHeight + 28

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: MiscState.popupCardBg
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

                Shortcut {
                    sequence: "Escape"
                    onActivated: MiscState.showCpuProcs = false
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: MiscState.showCpuProcs = false
                }

                ColumnLayout {
                    id: procCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 7

                    // header — mirrors the memory popup
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "\uf2db"
                            color: "#bd93f9"
                            font {
                                pixelSize: 12
                                family: "Symbols Nerd Font Mono"
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: `${Math.round(cpu.cpuTemp)}°`
                            color: cpu.tempColor(cpu.cpuTemp)
                            font {
                                pixelSize: 12
                                bold: true
                                family: "ZedMono Nerd Font"
                            }
                        }

                        // session extremes as min.max — e.g. 50.56 = min 50° max 56°
                        Text {
                            text: "min·max"
                            color: "#6272a4"
                            font {
                                pixelSize: 10
                                family: "ZedMono Nerd Font"
                            }
                        }

                        Text {
                            text: `${Math.round(cpu.tempMin)}.${Math.round(cpu.tempMax)}°`
                            color: cpu.tempColor(Math.min(cpu.tempMin, cpu.cpuTemp))
                            font {
                                pixelSize: 12
                                bold: true
                                family: "ZedMono Nerd Font"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#343746"
                    }

                    Repeater {
                        model: procModel

                        Rectangle {
                            id: prow

                            required property real c
                            required property int kib
                            required property int n
                            required property string name

                            readonly property real cval: c
                            readonly property color accent: cval > 80 ? "#ff5555" : cval > 40 ? "#f1fa8c" : "#bd93f9"

                            radius: 8
                            Layout.fillWidth: true
                            implicitHeight: prowCol.implicitHeight + 12
                            // hover highlight — the row under the cursor lights up
                            color: prowHover.containsMouse ? Qt.rgba(0.741, 0.576, 0.976, 0.12) : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            MouseArea {
                                id: prowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                z: -1
                            }

                            ColumnLayout {
                                id: prowCol

                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                RowLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: Number(prow.cval.toFixed(1)) + "%"
                                        color: prow.accent
                                        font {
                                            pixelSize: 11
                                            bold: true
                                            family: "ZedMono Nerd Font"
                                        }
                                        Layout.preferredWidth: 44
                                    }

                                    Text {
                                        text: prow.name
                                        color: "#f8f8f2"
                                        elide: Text.ElideRight
                                        font {
                                            pixelSize: 11
                                            family: "Quicksand"
                                        }
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: prow.n > 1
                                        text: "×" + prow.n
                                        color: "#6272a4"
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                        }
                                    }

                                    Text {
                                        text: ResourcesState.fmtKib(prow.kib)
                                        color: "#6272a4"
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                        }
                                        Layout.preferredWidth: 40
                                        Layout.alignment: Qt.AlignRight
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 6
                                    radius: 3
                                    color: Qt.rgba(1, 1, 1, 0.06)

                                    Rectangle {
                                        width: parent.width * Math.min(prow.cval / 100, 1)
                                        height: parent.height
                                        radius: 3
                                        color: prow.accent

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 250
                                                easing.type: Easing.OutQuad
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                        Text {
                            visible: procModel.count === 0
                            text: "sampling…"
                            color: "#6272a4"
                            font {
                                pixelSize: 10
                                italic: true
                                family: "Quicksand"
                            }
                            Layout.alignment: Qt.AlignHCenter
                        }

                    // poll-rate ghost footer
                    Text {
                        text: "polls 2s"
                        color: "#6272a4"
                        opacity: 0.45
                        font {
                            pixelSize: 8
                            letterSpacing: 2
                            family: "ZedMono Nerd Font"
                        }
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
