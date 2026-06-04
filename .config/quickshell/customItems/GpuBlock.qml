import QtQuick
import QtQuick.Layouts
import qs.services
import qs.customItems

BarBlock {
    id: gpu
    border.width: 0

    property bool showPercent: false
    property bool showTemp: false

    readonly property int gpuPercent: ResourcesState.gpuPercent
    readonly property real gpuTemp: ResourcesState.gpuTemp

    readonly property color gpuColor: gpuPercent > 80 ? "#f5a0d6" : gpuPercent > 60 ? "#c6a0f6" : "#a6e3a1"

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            showPercent = !showPercent;
        else if (mouse.button === Qt.RightButton)
            showTemp = !showTemp;
    }

    content: RowLayout {
        spacing: 4

        Canvas {
            id: gauge

            readonly property real progress: gpu.gpuPercent / 100

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
                    ctx.strokeStyle = gpu.gpuColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }

                ctx.fillStyle = gpu.gpuColor;
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.font = `11px "Symbols Nerd Font Mono"`;
                ctx.fillText("󰢩", cx, cy + 0.5);
            }
        }

        BarText {
            id: percentText
            visible: gpu.showPercent
            symbolText: `${gpu.gpuPercent}%`
            baseColor: gpu.gpuColor
            pointSize: 11
        }

        BarText {
            id: tempText
            visible: gpu.showTemp
            symbolText: `${gpu.gpuTemp}°`
            baseColor: gpu.gpuColor
            pointSize: 11
        }
    }
}
