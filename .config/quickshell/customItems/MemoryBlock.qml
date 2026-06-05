import QtQuick
import QtQuick.Layouts
import qs.services
import qs.customItems

BarBlock {
    id: memory

    property bool showPercent: false
    property bool showUsage: false
    property bool showSwap: false

    readonly property int memoryPercent: ResourcesState.memPercent
    readonly property real memoryUsed: ResourcesState.memUsed
    readonly property string memoryDetail: `${ResourcesState.memUsed.toFixed(1)}G / ${ResourcesState.memTotal.toFixed(1)}G`
    readonly property string swapInfo: ResourcesState.swapTotal > 0 ? ` ${ResourcesState.swapUsed.toFixed(1)}Gi` : ""

    readonly property color memoryColor: memoryPercent > 90 ? "#f38ba8" : memoryPercent > 80 ? "#f9e2af" : "#cba6f7"
    readonly property color swapColor: ResourcesState.swapPercent > 80 ? "#f38ba8" : "#89dceb"

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            showUsage = !showUsage;
        } else if (mouse.button === Qt.RightButton)
            showSwap = !showSwap;
        else if (mouse.button === Qt.MiddleButton)
            showPercent = !showPercent;
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
            id: percentText
            visible: memory.showPercent
            symbolText: `${memory.memoryPercent}%`
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
}
