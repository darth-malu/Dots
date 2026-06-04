import QtQuick
import qs.services
import qs.customItems
import qs.themes

BarBlock {
    id: cpu
    border.width: 0

    property bool showTemp: false

    readonly property int cpuPercent: ResourcesState.cpuUsageString

    readonly property color cpuColor: cpuPercent > 80 ? "#7CE577" : cpuPercent > 50 ? "#7CE577" : '#C6CAED'

    readonly property real cpuFreq: ResourcesState.cpuFreq
    readonly property real cpuTemp: ResourcesState.cpuTemp

    readonly property color cpuTempColor: this.cpuTemp > 80 ? "red" : this.cpuTemp > 60 ? "orange" : 'grey'

    onClicked: {
        showTemp = !showTemp;
    }

    content: Item {
        Text {
            id: sizeHelper
            visible: false
            text: showTemp ? ` ${cpu.cpuPercent} ${cpu.cpuTemp}°` : ` ${cpu.cpuPercent}`
            font: Themes.zedMono
        }

        implicitWidth: sizeHelper.implicitWidth + sizeHelper.implicitHeight + 4
        implicitHeight: sizeHelper.implicitHeight

        Canvas {
            id: gauge
            anchors.fill: parent

            readonly property real progress: cpu.cpuPercent / 100
            readonly property string displayText: cpu.showTemp
                ? ` ${cpu.cpuPercent} ${cpu.cpuTemp}°`
                : ` ${cpu.cpuPercent}`

            onProgressChanged: requestPaint()
            onDisplayTextChanged: requestPaint()

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
                    ctx.strokeStyle = cpu.cpuColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }

                ctx.fillStyle = cpu.cpuColor;
                ctx.font = `bold 12px "${Themes.zedMono.family}", "Symbols Nerd Font Mono"`;
                ctx.textAlign = "left";
                ctx.textBaseline = "middle";
                ctx.fillText(displayText, ringSize + 3, height / 2);
            }
        }
    }
}
