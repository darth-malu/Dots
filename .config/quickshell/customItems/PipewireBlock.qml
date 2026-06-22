import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.customItems
import qs.services

BarBlock {
    id: root
    visible: PipewireState.pipewireReady
    color: Qt.rgba(1, 1, 1, 0.19)

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
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 4

        BarText {
            symbolText: root.muted ? "婢" : root.vol > 0.7 ? "" : root.vol > 0.05 ? "" : ""
            baseColor: root.volColor
            pointSize: 10
        }

        Item {
            id: volBar
            implicitWidth: 40
            implicitHeight: 4

            Rectangle {
                anchors.fill: parent
                radius: 2
                color: "#313244"

                Rectangle {
                    width: parent.width * Math.min(root.vol, 1)
                    height: parent.height
                    radius: 2
                    color: root.volColor
                }
            }

            MouseArea {
                id: volSeeker
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (Pipewire.defaultAudioSink?.audio)
                        Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(mouse.x / width, 1));
                }
            }
        }
    }
}
