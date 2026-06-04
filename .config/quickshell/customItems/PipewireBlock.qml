import QtQuick
import Quickshell.Services.Pipewire
import qs.customItems
import qs.themes
import QtQuick.Layouts
import qs.services

BarBlock {
    id: root
    visible: PipewireState.pipewireReady

    readonly property color volumeColor: "#ccccccff"

    readonly property real volumePercent: parseFloat(PipewireState.outputVolume) || 0

    onClicked: mouse => {
        if (mouse.button == Qt.LeftButton)
            NetworkState.netspeedVisible = !NetworkState.netspeedVisible;
        else if (mouse.button == Qt.RightButton)
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
    }

    content: RowLayout {
        spacing: 0

        Item {
            Text {
                id: sizeHelper
                visible: false
                text: ` ${PipewireState.outputVolume}`
                font: Themes.zedMono
            }

            implicitWidth: sizeHelper.implicitWidth + sizeHelper.implicitHeight + 4
            implicitHeight: sizeHelper.implicitHeight

            Canvas {
                anchors.fill: parent

                readonly property real progress: root.volumePercent / 100
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
                        ctx.strokeStyle = root.volumeColor;
                        ctx.lineWidth = lw;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }

                    ctx.fillStyle = root.volumeColor;
                    ctx.font = `bold 12px "${Themes.zedMono.family}", "Symbols Nerd Font Mono"`;
                    ctx.textAlign = "left";
                    ctx.textBaseline = "middle";
                    ctx.fillText(` ${PipewireState.outputVolume}`, ringSize + 3, height / 2);
                }
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
            id: inputSink
            symbolText: `🎙️ ${PipewireState.inputVolume} `
            color: root.volumeColor
            visible: PipewireState.isCrusherWireless
            renderNative: true
            font: Themes.quicksand

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
                        NetworkState.netspeedVisible = !NetworkState.netspeedVisible;
                    else if (mouse.button == Qt.RightButton)
                        Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
                }
            }
        }
    }
}
