import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.customItems
import qs.services

BarBlock {
    id: root
    visible: PipewireState.pipewireReady

    readonly property real vol: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    readonly property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

    readonly property color volColor: muted ? "#585b70" :
        vol > 0.7 ? "#f5a0d6" :
        vol > 0.4 ? "#c6a0f6" : "#89b4fa"

    onWheel: event => {
        if (!Pipewire.defaultAudioSink?.audio) return;
        const step = 4;
        let v = Pipewire.defaultAudioSink.audio.volume * 100;
        v += event.angleDelta.y > 0 ? step : -step;
        v = Math.max(0, Math.min(v, 100));
        Pipewire.defaultAudioSink.audio.volume = v / 100;
    }

    onClicked: mouse => {
        if (mouse.button == Qt.RightButton)
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
    }

    content: RowLayout {
        spacing: 6

        Item {
            implicitWidth: 48
            Layout.fillHeight: true

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 5
                radius: 3
                color: "#313244"

                Rectangle {
                    width: parent.width * Math.min(root.vol, 1)
                    height: parent.height
                    radius: 3
                    color: root.volColor
                }
            }
        }

        BarText {
            symbolText: `🖊 ${PipewireState.inputVolume} `
            baseColor: root.volColor
            visible: PipewireState.isCrusherWireless
            renderNative: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onWheel: event => {
                    if (!PipewireState.inputSink?.audio) return;
                    const step = 4;
                    let v = PipewireState.inputSink.audio.volume * 100;
                    v += event.angleDelta.y > 0 ? step : -step;
                    v = Math.max(0, Math.min(v, 100));
                    Pipewire.defaultAudioSource.audio.volume = v / 100;
                }

                onClicked: mouse => {
                    if (mouse.button == Qt.RightButton)
                        Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
                }
            }
        }
    }
}
