import QtQuick
import Quickshell.Services.Pipewire
import qs.customItems
import qs.themes
import QtQuick.Layouts
import qs.services

BarBlock {
    id: root
    visible: PipewireState.pipewireReady

    //underline: true
    readonly property int textSize: 8
    property string textFont: 'ZedMono Nerd Font'
    readonly property bool textBold: true
    readonly property color volumeColor: "#ccccccff"

    onClicked: mouse => {
        // When handling this signal, changing the accepted property of the mouse parameter has no effect, unless the propagateComposedEvents property is true.
        if (mouse.button == Qt.LeftButton)
            NetworkState.netspeedVisible = !NetworkState.netspeedVisible;
        else if (mouse.button == Qt.RightButton) {
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
        }
    }
    content: RowLayout {
        BarText {
            id: outputSink
            symbolText: ` ${PipewireState.outputVolume}` /*󰓃*/
            color: root.volumeColor
            renderNative: true
            font: Themes.zedMono
            leftPadding: 0
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (!PipewireState.outputSink?.audio)
                        return;
                    const step = 4;
                    let volume = PipewireState.outputSink.audio.volume * 100;
                    volume += event.angleDelta.y > 0 ? step : -step;
                    volume = Math.max(0, Math.min(volume, 100));
                    // Pipewire.defaultAudioSink.audio.volume = volume / 100;
                    if (!PipewireState.outputSink.audio.muted)
                        PipewireState.outputSink.audio.volume = volume / 100;
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
                    let volume = PipewireState.inputSink.audio.volume * 100;
                    volume += event.angleDelta.y > 0 ? step : -step;
                    volume = Math.max(0, Math.min(volume, 100)); // Clamp 0% - 100% even with continued scrolling
                    Pipewire.defaultAudioSource.audio.volume = volume / 100;
                }

                onClicked: mouse => {
                    // mouse.accepted = true;
                    if (mouse.button == Qt.LeftButton)
                        NetworkState.netspeedVisible = !NetworkState.netspeedVisible;
                    else if (mouse.button == Qt.RightButton) {
                        Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
                    }
                }
            }
        }
    }
}
