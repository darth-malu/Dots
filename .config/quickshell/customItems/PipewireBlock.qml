import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.customItems
import qs.services

BarBlock {
    id: root
    visible: PipewireState.pipewireReady

    property bool showPercent: false

    readonly property color volumeColor: "#82aaff"

    readonly property real volumePercent: parseFloat(PipewireState.outputVolume) || 0

    onClicked: mouse => {
        if (mouse.button == Qt.LeftButton)
            showPercent = !showPercent;
        else if (mouse.button == Qt.RightButton)
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
    }

    content: RowLayout {
        spacing: 4

        Canvas {
            id: volGauge

            readonly property real progress: root.volumePercent / 100
            readonly property bool isMuted: PipewireState.outputSink?.audio?.muted ?? false

            implicitWidth: 22
            implicitHeight: 22

            onProgressChanged: requestPaint()
            onIsMutedChanged: requestPaint()

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
                    ctx.strokeStyle = isMuted ? "#54546b" : root.volumeColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }

                ctx.fillStyle = isMuted ? "#54546b" : root.volumeColor;
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.font = `11px "Symbols Nerd Font Mono"`;
                ctx.fillText(isMuted ? "" : "", cx, cy + 0.5);
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (!PipewireState.outputSink?.audio)
                        return;
                    const step = 4;
                    let vol = PipewireState.outputSink.audio.volume * 100;
                    vol += event.angleDelta.y > 0 ? step : -step;
                    vol = Math.max(0, Math.min(vol, 100));
                    if (!PipewireState.outputSink.audio.muted)
                        PipewireState.outputSink.audio.volume = vol / 100;
                }
            }
        }

        BarText {
            id: volumeText
            visible: root.showPercent
            symbolText: `${PipewireState.outputVolume}`
            baseColor: root.volumeColor
            pointSize: 11
        }

        BarText {
            id: inputSink
            symbolText: `🎙️ ${PipewireState.inputVolume} `
            baseColor: root.volumeColor
            visible: PipewireState.isCrusherWireless
            renderNative: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    if (!PipewireState.inputSink?.audio)
                        return;
                    const step = 4;
                    let vol = PipewireState.inputSink.audio.volume * 100;
                    vol += event.angleDelta.y > 0 ? step : -step;
                    vol = Math.max(0, Math.min(vol, 100));
                    Pipewire.defaultAudioSource.audio.volume = vol / 100;
                }

                onClicked: mouse => {
                    if (mouse.button == Qt.LeftButton)
                        root.showPercent = !root.showPercent;
                    else if (mouse.button == Qt.RightButton)
                        Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
                }
            }
        }
    }
}
