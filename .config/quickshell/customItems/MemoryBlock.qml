import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.customItems

BarBlock {
    id: memory

    required property var host

    property bool showUsage: false
    property bool showSwap: false

    property var topProcs: []

    // converts a memory percentage into an absolute figure based on total RAM
    function fmtMem(pct) {
        const mib = pct / 100 * ResourcesState.memTotal * 1024;
        return mib >= 1024 ? (mib / 1024).toFixed(1) + "G" : Math.round(mib) + "M";
    }

    readonly property int memoryPercent: ResourcesState.memPercent
    readonly property real memoryUsed: ResourcesState.memUsed
    readonly property string memoryDetail: `${ResourcesState.memUsed.toFixed(1)}G / ${ResourcesState.memTotal.toFixed(1)}G`
    readonly property string swapInfo: ResourcesState.swapTotal > 0 ? ` ${ResourcesState.swapUsed.toFixed(1)}Gi` : ""

    readonly property color memoryColor: memoryPercent > 90 ? "#ff5555" : memoryPercent > 80 ? "#f1fa8c" : "#bd93f9"
    readonly property color swapColor: ResourcesState.swapPercent > 80 ? "#ff5555" : "#8be9fd"

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            showUsage = !showUsage;
        } else if (mouse.button === Qt.RightButton)
            showSwap = !showSwap;
        else if (mouse.button === Qt.MiddleButton)
            MiscState.showMemProcs = !MiscState.showMemProcs;
    }

    content: RowLayout {
        spacing: 4

        Canvas {
            id: gauge

            readonly property real progress: memory.memoryPercent / 100

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
                    ctx.strokeStyle = memory.memoryColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }

                ctx.fillStyle = memory.memoryColor;
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.font = `11px "Symbols Nerd Font Mono"`;
                ctx.fillText("", cx, cy + 0.5);
            }
        }

        BarText {
            id: usageText
            visible: memory.showUsage
            symbolText: `${memory.memoryUsed} Gi`
            baseColor: memory.memoryColor
            pointSize: 11
        }

        BarText {
            id: swapText
            visible: memory.showSwap
            symbolText: memory.swapInfo
            baseColor: memory.swapColor
            pointSize: 11
        }
    }

    Process {
        id: memProcsProc
        // aggregate memory usage by process name (all subprocesses summed into one entry)
        command: ["sh", "-c", "ps -eo pmem,comm --no-headers | awk '{m=$1; $1=\"\"; sub(/^ +/, \"\"); k=$0; mm[k]+=m; cnt[k]++} END {for (k in mm) printf \"%.1f %d %s\\n\", mm[k], cnt[k], k}' | sort -rn | head -10"]
        property string buf: ""
        running: false

        stdout: SplitParser {
            onRead: data => memProcsProc.buf += data + "\n"
        }

        onExited: {
            const rows = [];
            for (const line of memProcsProc.buf.trim().split("\n")) {
                const p = line.trim().split(/\s+/);
                if (p.length >= 3)
                    rows.push({
                        m: parseFloat(p[0]) || 0,
                        c: parseInt(p[1]) || 1,
                        n: p.slice(2).join(" ")
                    });
            }
            memory.topProcs = rows;
            memProcsProc.buf = "";
        }
    }

    Timer {
        interval: 5000
        running: MiscState.showMemProcs
        repeat: true
        triggeredOnStart: true
        onTriggered: memProcsProc.running = true
    }

    LazyLoader {
        loading: true

        PopupWindow {
            id: memPopup
            visible: MiscState.showMemProcs
            grabFocus: true
            color: "transparent"

            anchor.window: memory.host
            anchor.rect.x: {
                let g = memory.mapToGlobal(0, 0);
                return g.x + (memory.width / 2) - (width / 2);
            }
            anchor.rect.y: 33

            implicitWidth: 300
            implicitHeight: Math.min(memCol.implicitHeight + 28, 240)

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#282a36"
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

                Shortcut {
                    sequence: "Escape"
                    onActivated: MiscState.showMemProcs = false
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: MiscState.showMemProcs = false
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 14
                    contentHeight: memCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: memCol
                        width: parent.width
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "memory"
                                color: "#6272a4"
                                font {
                                    pixelSize: 9
                                    bold: true
                                    family: "Quicksand"
                                    letterSpacing: 1
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: `${memory.memoryDetail} · ${memory.memoryPercent}%`
                                color: memory.memoryColor
                                font {
                                    pixelSize: 9
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
                            model: memory.topProcs

                            RowLayout {
                                id: mrow
                                required property var modelData

                                readonly property real mval: modelData?.m ?? 0
                                readonly property int pcount: modelData?.c ?? 1
                                readonly property color accent: mval > 25 ? "#ff5555" : mval > 10 ? "#f1fa8c" : "#bd93f9"

                                spacing: 8
                                Layout.fillWidth: true

                                Text {
                                    text: Number(mrow.mval.toFixed(1)) + "%"
                                    color: mrow.accent
                                    font {
                                        pixelSize: 10
                                        bold: true
                                        family: "ZedMono Nerd Font"
                                    }
                                    Layout.preferredWidth: 40
                                }

                                RowLayout {
                                    spacing: 4
                                    Layout.fillWidth: true

                                    Text {
                                        text: mrow.modelData?.n ?? ""
                                        color: "#f8f8f2"
                                        elide: Text.ElideRight
                                        font {
                                            pixelSize: 10
                                            family: "Quicksand"
                                        }
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: mrow.pcount > 1
                                        text: "×" + mrow.pcount
                                        color: "#6272a4"
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                        }
                                    }
                                }

                                Text {
                                    text: memory.fmtMem(mrow.mval)
                                    color: "#b8bfcb"
                                    font {
                                        pixelSize: 10
                                        family: "ZedMono Nerd Font"
                                    }
                                    Layout.preferredWidth: 44
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }

                        Text {
                            visible: memory.topProcs.length === 0
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
}
