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

    property bool showPercent: false

    property bool showTemp: false

    readonly property int cpuPercent: ResourcesState.cpuUsageString
    readonly property real cpuTemp: ResourcesState.cpuTemp

    readonly property color cpuColor: cpuPercent > 80 ? "#ff5555" : cpuPercent > 60 ? "#f1fa8c" : "#bd93f9"

    property var topProcs: []

    // converts a memory percentage into an absolute figure based on total RAM
    function fmtMem(pct) {
        const mib = pct / 100 * ResourcesState.memTotal * 1024;
        return mib >= 1024 ? (mib / 1024).toFixed(1) + "G" : Math.round(mib) + "M";
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            showPercent = !showPercent;
        else if (mouse.button === Qt.RightButton)
            showTemp = !showTemp;
        else if (mouse.button === Qt.MiddleButton)
            MiscState.showCpuProcs = !MiscState.showCpuProcs;
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

        BarText {
            id: percentText
            visible: cpu.showPercent
            symbolText: `${cpu.cpuPercent}%`
            baseColor: cpu.cpuColor
            pointSize: 11
        }

        BarText {
            id: tempText
            visible: cpu.showTemp
            symbolText: `${cpu.cpuTemp}°`
            baseColor: cpu.cpuColor
            pointSize: 11
        }
    }

    Process {
        id: procsProc
        // aggregate cpu/memory usage by process name (all subprocesses summed into one entry)
        command: ["sh", "-c", "ps -eo pcpu,pmem,comm --no-headers | awk '{c=$1; m=$2; $1=$2=\"\"; sub(/^ +/, \"\"); k=$0; cc[k]+=c; mm[k]+=m; cnt[k]++} END {for (k in cc) printf \"%.1f %.1f %d %s\\n\", cc[k], mm[k], cnt[k], k}' | sort -rn | head -10"]
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
                        m: parseFloat(p[1]) || 0,
                        n: parseInt(p[2]) || 1,
                        name: p.slice(3).join(" ")
                    });
            }
            cpu.topProcs = rows;
            procsProc.buf = "";
        }
    }

    Timer {
        interval: 5000
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

            implicitWidth: 320
            implicitHeight: procCol.implicitHeight + 28

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#282a36"
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
                    spacing: 9

                    Repeater {
                        model: cpu.topProcs

                        ColumnLayout {
                            id: prow
                            required property var modelData

                            readonly property real cval: modelData?.c ?? 0
                            readonly property color accent: cval > 80 ? "#ff5555" : cval > 40 ? "#f1fa8c" : "#bd93f9"

                            spacing: 4
                            Layout.fillWidth: true

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
                                    text: prow.modelData?.name ?? ""
                                    color: "#f8f8f2"
                                    elide: Text.ElideRight
                                    font {
                                        pixelSize: 11
                                        family: "Quicksand"
                                    }
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: (prow.modelData?.n ?? 1) > 1
                                    text: "×" + (prow.modelData?.n ?? 1)
                                    color: "#6272a4"
                                    font {
                                        pixelSize: 9
                                        family: "ZedMono Nerd Font"
                                    }
                                }

                                Text {
                                    text: cpu.fmtMem(prow.modelData?.m ?? 0)
                                    color: "#6272a4"
                                    font {
                                        pixelSize: 9
                                        family: "ZedMono Nerd Font"
                                    }
                                    Layout.preferredWidth: 44
                                    Layout.alignment: Qt.AlignRight
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 3
                                radius: 1.5
                                color: Qt.rgba(1, 1, 1, 0.06)

                                Rectangle {
                                    width: parent.width * Math.min(prow.cval / 100, 1)
                                    height: parent.height
                                    radius: 1.5
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

                    Text {
                        visible: cpu.topProcs.length === 0
                        text: "sampling…"
                        color: "#6272a4"
                        font {
                            pixelSize: 10
                            italic: true
                            family: "Quicksand"
                        }
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
