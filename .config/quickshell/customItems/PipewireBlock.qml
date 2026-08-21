import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.customItems
import qs.services
import Quickshell

BarBlock {
    id: root
    visible: PipewireState.pipewireReady

    readonly property real vol: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    readonly property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

    // readonly property color volColor: muted ? "#6272a4" : vol > 0.7 ? "#ff79c6" : vol > 0.4 ? "#c6a0f6" : "#bd93f9"

    readonly property color volColor: {
        if (root.muted)
            return "#6272a4";
        var v = root.vol;
        if (v > 0.8)
            return "#ff79c6";
        if (v > 0.5)
            return "#c6a0f6";
        if (v > 0.2)
            return "#bd93f9";
        return "#bd93f9";
    }

    property bool hovering: false
    property real targetVol: vol

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
        else if (mouse.button == Qt.LeftButton)
            Quickshell.execDetached(['hyprpwcenter']);
    }

    content: RowLayout {
        spacing: 6

        Item {
            id: volBar
            implicitWidth: 48
            implicitHeight: 6

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: "#343746"

                Rectangle {
                    radius: 3
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.min(root.vol, 1)
                    color: root.volColor
                    Behavior on width {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: root.volColor
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                        opacity: root.hovering ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: volSeeker
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: root.hovering = true
                onExited: root.hovering = false
                onPositionChanged: mouse => {
                    if (pressed && Pipewire.defaultAudioSink?.audio)
                        Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(mouse.x / width, 1));
                }
                onClicked: mouse => {
                    if (Pipewire.defaultAudioSink?.audio)
                        Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(mouse.x / width, 1));
                }
            }
        }

        Text {
            text: Math.round(root.vol * 100) + "%"
            color: root.volColor
            font {
                pixelSize: 9
                family: "ZedMono Nerd Font"
                bold: true
            }
            opacity: root.hovering ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
            visible: root.hovering
        }
    }
}
