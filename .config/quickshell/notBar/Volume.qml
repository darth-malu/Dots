pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.themes

Scope {
    id: root
    property bool shouldShowOsd: false
    property var defaultSink: Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource
    property var ifAudioNode: defaultSink?.audio
    property bool isMuted: ifAudioNode?.muted ?? false

    readonly property color volColor: {
        if (root.isMuted) return "#585b70";
        var v = ifAudioNode?.volume ?? 0;
        if (v > 0.8) return "#f5a0d6";
        if (v > 0.5) return "#c6a0f6";
        if (v > 0.2) return "#89b4fa";
        return "#b4befe";
    }

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

        implicitWidth: 40
        implicitHeight: 200
        color: "transparent"
        mask: Region {}

        Item {
            anchors.fill: parent
            opacity: root.shouldShowOsd ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.rgba(0.04, 0.01, 0.1, 0.75)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                Item {
                    id: bottomDeck
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 34

                    Text {
                        anchors.centerIn: parent
                        text: root.isMuted ? "" : Math.floor((ifAudioNode?.volume ?? 0) * 100)
                        color: root.volColor
                        font {
                            pixelSize: root.isMuted ? 16 : 15
                            family: root.isMuted ? "Symbols Nerd Font Mono" : "Quicksand"
                            bold: true
                            letterSpacing: root.isMuted ? 0 : 1
                        }
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.4)
                    }
                }

                Rectangle {
                    id: bar
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: bottomDeck.top
                        margins: 6
                    }
                    height: (parent.height - bottomDeck.height - 12) * (ifAudioNode?.volume ?? 0)
                    radius: 5
                    color: root.volColor

                    Behavior on height {
                        NumberAnimation { duration: 100 }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left; right: parent.right; top: parent.top
                        }
                        height: parent.height * 0.4
                        radius: 5
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }
                }
            }
        }
    }
}
