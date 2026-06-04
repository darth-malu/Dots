import QtQuick
import QtQuick.Layouts
import qs.services
import qs.customItems

BarBlock {
    id: cpu
    border.width: 0

    property bool showPercent: false

    readonly property int cpuPercent: ResourcesState.cpuUsageString

    readonly property color cpuColor: cpuPercent > 80 ? "#ff5370" : cpuPercent > 60 ? "#ffcb6b" : "#82aaff"

    onClicked: {
        showPercent = !showPercent;
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
                ctx.strokeStyle = "#2a2a3a";
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
            symbolText: `${cpu.cpuPercent}`
            baseColor: cpu.cpuColor
            pointSize: 11
        }
    }
}
