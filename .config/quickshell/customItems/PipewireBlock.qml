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

    readonly property color volColor: muted ? "#585b70" : vol > 0.7 ? "#f5a0d6" : vol > 0.4 ? "#c6a0f6" : "#89b4fa"

    onWheel: event => {
        if (!Pipewire.defaultAudioSink?.audio)
            return;
        let v = Pipewire.defaultAudioSink.audio.volume;
        v += event.angleDelta.y > 0 ? 0.05 : -0.05;
        Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(v, 1));
    }

    onClicked: mouse => {
        if (mouse.button == Qt.RightButton)
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
    }

    content: RowLayout {
        spacing: 6

        Item {
            id: volBar
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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button == Qt.LeftButton && Pipewire.defaultAudioSink?.audio)
                        Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(mouse.x / width, 1));
                }
                onWheel: event => {
                    if (Pipewire.defaultAudioSink?.audio) {
                        let v = Pipewire.defaultAudioSink.audio.volume;
                        v += event.angleDelta.y > 0 ? 0.05 : -0.05;
                        Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(v, 1));
                    }
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
                    if (!PipewireState.inputSink?.audio)
                        return;
                    let v = PipewireState.inputSink.audio.volume;
                    v += event.angleDelta.y > 0 ? 0.05 : -0.05;
                    v = Math.max(0, Math.min(v, 1));
                    Pipewire.defaultAudioSource.audio.volume = v;
                }

                onClicked: mouse => {
                    if (mouse.button == Qt.RightButton)
                        Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
                }
            }
        }
    }
}
