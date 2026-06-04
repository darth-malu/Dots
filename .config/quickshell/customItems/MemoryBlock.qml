import QtQuick
import qs.services
import qs.themes

BarBlock {
    id: memory

    readonly property int memoryPercent: ResourcesState.memPercent

    readonly property color memoryColor: memoryPercent > 90 ? "#7CE577" : '#ccccccff'

    content: Item {
        Text {
            id: sizeHelper
            visible: false
            text: ` ${memory.memoryPercent}`
            font: Themes.zedMono
        }

        implicitWidth: sizeHelper.implicitWidth + sizeHelper.implicitHeight + 4
        implicitHeight: sizeHelper.implicitHeight

        Canvas {
            anchors.fill: parent

            readonly property real progress: memory.memoryPercent / 100
            onProgressChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var ringSize = height;
                var cx = ringSize / 2;
                var cy = ringSize / 2;
                var r = ringSize / 2 - 1.5;
                var lw = 2;

                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.strokeStyle = "#333";
                ctx.lineWidth = lw;
                ctx.stroke();

                if (progress > 0) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(progress, 1));
                    ctx.strokeStyle = memory.memoryColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }

                ctx.fillStyle = memory.memoryColor;
                ctx.font = `bold 12px "${Themes.zedMono.family}", "Symbols Nerd Font Mono"`;
                ctx.textAlign = "left";
                ctx.textBaseline = "middle";
                ctx.fillText(` ${memory.memoryPercent}`, ringSize + 3, height / 2);
            }
        }
    }
}
