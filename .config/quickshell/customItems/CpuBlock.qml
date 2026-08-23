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

    property bool showTemp: false

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

    // popup view switcher — 0 = process list, 1 = usage graph
    property int popupTab: 0

    // rolling cpu samples for the graph tab (1/s while the popup is open)
    property var cpuHistory: []
    property int graphTick: 0
    readonly property int historyMax: 60

    function pushCpuSample() {
        cpuHistory.push(cpuPercent);
        if (cpuHistory.length > historyMax)
            cpuHistory.shift();
        graphTick++;
    }

    Timer {
        interval: 1000
        running: MiscState.showCpuProcs
        repeat: true
        triggeredOnStart: true
        onTriggered: cpu.pushCpuSample()
    }

    function tempColor(t) {
        if (t >= 75)
            return "#ff5555";
        if (t >= 62)
            return "#ffb86c";
        if (t >= 45)
            return "#f1fa8c";
        return "#8be9fd";
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            showTemp = !showTemp;
        else if (mouse.button === Qt.RightButton)
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
            id: tempText
            visible: cpu.showTemp
            symbolText: `${cpu.cpuTemp}°`
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

            implicitWidth: 340
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
                            text: `${cpu.cpuPercent}% ·`
                            color: cpu.cpuColor
                            font {
                                pixelSize: 9
                                family: "ZedMono Nerd Font"
                            }
                        }

                        Text {
                            text: `${Math.round(cpu.cpuTemp)}°`
                            color: cpu.tempColor(cpu.cpuTemp)
                            font {
                                pixelSize: 9
                                bold: true
                                family: "ZedMono Nerd Font"
                            }
                        }

                        // session extremes as min.max — e.g. 50.56 = min 50° max 56°
                        Text {
                            text: "min·max"
                            color: "#6272a4"
                            font {
                                pixelSize: 9
                                family: "ZedMono Nerd Font"
                            }
                        }

                        Text {
                            text: `${Math.round(cpu.tempMin)}.${Math.round(cpu.tempMax)}°`
                            color: cpu.tempColor(Math.min(cpu.tempMin, cpu.cpuTemp))
                            font {
                                pixelSize: 9
                                bold: true
                                family: "ZedMono Nerd Font"
                            }
                        }
                    }

                    // ── view tabs — process list / usage graph ──
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 0

                        Rectangle {
                            implicitWidth: 170
                            implicitHeight: 22
                            radius: 8
                            color: "#21222c"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 2
                                spacing: 2

                                Rectangle {
                                    radius: 6
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: cpu.popupTab === 0 ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.18) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "processes"
                                        color: cpu.popupTab === 0 ? "#bd93f9" : "#6272a4"
                                        font { pixelSize: 9; bold: cpu.popupTab === 0; family: "Quicksand" }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: cpu.popupTab = 0
                                    }
                                }

                                Rectangle {
                                    radius: 6
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: cpu.popupTab === 1 ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.18) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "graph"
                                        color: cpu.popupTab === 1 ? "#bd93f9" : "#6272a4"
                                        font { pixelSize: 9; bold: cpu.popupTab === 1; family: "Quicksand" }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: cpu.popupTab = 1
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#343746"
                    }

                    // ── tab 0 — top processes ──
                    ColumnLayout {
                        visible: cpu.popupTab === 0
                        Layout.fillWidth: true
                        spacing: 7

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
                    }

                    // ── tab 1 — live usage graph ──
                    ColumnLayout {
                        visible: cpu.popupTab === 1
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: `${cpu.cpuPercent}%`
                                color: cpu.cpuColor
                                font {
                                    pixelSize: 24
                                    bold: true
                                    family: "ZedMono Nerd Font"
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            ColumnLayout {
                                spacing: 1

                                Text {
                                    text: `now ${cpu.cpuPercent}% · ${Math.round(cpu.cpuTemp)}°`
                                    color: "#b8bfcb"
                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text {
                                    text: `${cpu.cpuHistory.length}/${cpu.historyMax} samples · polls 1s`
                                    color: "#6272a4"
                                    font { pixelSize: 8; family: "ZedMono Nerd Font" }
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }

                        Rectangle {
                            id: cpuGraphPanel
                            Layout.fillWidth: true
                            implicitHeight: 130
                            radius: 10
                            color: "#21222c"
                            clip: true

                            onGraphTickChanged: gcanvas.requestPaint()

                            readonly property int graphTick: cpu.graphTick
                            onWidthChanged: gcanvas.requestPaint()

                            Text {
                                anchors.centerIn: parent
                                visible: cpu.cpuHistory.length < 2
                                text: "gathering samples…"
                                color: "#6272a4"
                                font {
                                    pixelSize: 10
                                    italic: true
                                    family: "Quicksand"
                                }
                            }

                            Canvas {
                                id: gcanvas

                                anchors.fill: parent
                                anchors.margins: 6
                                antialiasing: true
                                renderStrategy: Canvas.Immediate
                                visible: cpu.cpuHistory.length >= 2

                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    const h = cpu.cpuHistory;
                                    if (h.length < 2)
                                        return;

                                    const stepX = width / (Math.max(cpu.historyMax, 2) - 1);
                                    const x0 = width - (h.length - 1) * stepX;
                                    const yAt = i => height - Math.min(1, h[i] / 100) * (height - 4) - 2;

                                    // area fill
                                    const grad = ctx.createLinearGradient(0, 0, 0, height);
                                    grad.addColorStop(0, Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.35));
                                    grad.addColorStop(1, Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.02));

                                    ctx.beginPath();
                                    ctx.moveTo(x0, height);
                                    for (let i = 0; i < h.length; i++)
                                        ctx.lineTo(x0 + i * stepX, yAt(i));
                                    ctx.lineTo((h.length - 1) * stepX + x0, height);
                                    ctx.closePath();
                                    ctx.fillStyle = grad;
                                    ctx.fill();

                                    // stroke line
                                    ctx.beginPath();
                                    for (let i = 0; i < h.length; i++) {
                                        if (i === 0)
                                            ctx.moveTo(x0 + i * stepX, yAt(i));
                                        else
                                            ctx.lineTo(x0 + i * stepX, yAt(i));
                                    }
                                    ctx.strokeStyle = "#bd93f9";
                                    ctx.lineWidth = 1.5;
                                    ctx.stroke();

                                    // hot threshold hairline at 80%
                                    ctx.beginPath();
                                    ctx.setLineDash([3, 4]);
                                    ctx.moveTo(0, height - 0.8 * (height - 4) - 2);
                                    ctx.lineTo(width, height - 0.8 * (height - 4) - 2);
                                    ctx.strokeStyle = "rgba(255, 85, 85, 0.35)";
                                    ctx.lineWidth = 1;
                                    ctx.stroke();
                                    ctx.setLineDash([]);
                                }
                            }
                        }
                    }

                    // poll-rate ghost footer (process list only)
                    Text {
                        visible: cpu.popupTab === 0
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
