pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root
    property bool shouldShowOsd: false
    property var defaultSink: Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource
    property var ifAudioNode: defaultSink?.audio
    property bool isMuted: ifAudioNode?.muted ?? false

    PwObjectTracker {
        objects: [root.defaultSink, root.defaultSource]
    }

    Connections {
        target: root.ifAudioNode ?? null

        function onVolumeChanged() {
            root.shouldShowOsd = true;
            root.isMuted = ifAudioNode?.muted ?? false;
            hideTimer.restart();
        }

        function onMutedChanged() {
            root.shouldShowOsd = true;
            root.isMuted = ifAudioNode?.muted ?? false;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.shouldShowOsd = false
    }

    PanelWindow {
        id: osdWindow
        visible: root.shouldShowOsd
        anchors.right: true
        margins.right: screen.width / 95
        exclusiveZone: 0

        implicitWidth: 56
        implicitHeight: 220
        color: "transparent"
        mask: Region {}

        Item {
            anchors.fill: parent
            opacity: root.shouldShowOsd ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Qt.rgba(0.06, 0.02, 0.12, 0.75)
                border.color: root.isMuted ? "#45475a" : "#c6a0f6"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0; color: Qt.rgba(0.7, 0.4, 0.9, 0.12) }
                        GradientStop { position: 1; color: Qt.rgba(0.7, 0.4, 0.9, 0) }
                    }
                }

                Rectangle {
                    id: bar
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 6
                    }
                    height: (parent.height - 12) * (ifAudioNode?.volume ?? 0)
                    radius: 6
                    color: {
                        if (root.isMuted) return "#585b70";
                        var v = ifAudioNode?.volume ?? 0;
                        if (v > 0.8) return "#f5a0d6";
                        if (v > 0.5) return "#c6a0f6";
                        if (v > 0.2) return "#89b4fa";
                        return "#b4befe";
                    }

                    Behavior on height {
                        NumberAnimation { duration: 100 }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left; right: parent.right; top: parent.top
                        }
                        height: parent.height * 0.5
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.isMuted ? "" : Math.floor((ifAudioNode?.volume ?? 0) * 100) + "%"
                    color: root.isMuted ? "#6c7086" : "#f5e0dc"
                    font {
                        pixelSize: root.isMuted ? 22 : 18
                        family: root.isMuted ? "Symbols Nerd Font Mono" : "Quicksand"
                        bold: true
                    }
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.3)
                }
            }
        }
    }
}
