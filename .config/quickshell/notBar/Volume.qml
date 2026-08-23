pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.themes
import qs.services

Scope {
    id: root
    property bool shouldShowOsd: VolumeState.shouldShowOsd
    property var ifAudioNode: VolumeState.isAudioNode

    readonly property real nodeVolume: ifAudioNode?.volume ?? 0
    readonly property bool nodeMuted: ifAudioNode?.muted ?? false

    readonly property color volColor: {
        if (root.nodeMuted)
            return "#6272a4";
        var v = root.nodeVolume;
        if (v > 0.8)
            return "#ff79c6";
        if (v > 0.5)
            return "#c6a0f6";
        return "#bd93f9";
    }

    PwObjectTracker {
        objects: [VolumeState.defaultSink]
    }

    Connections {
        target: root.ifAudioNode ?? null

        function onVolumeChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }

        function onMutedChanged() {
            root.shouldShowOsd = true;
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
        visible: root.shouldShowOsd && !MiscState.qsOpen
        anchors.right: true
        margins.right: screen.width / 95
        exclusiveZone: 0

        implicitWidth: 38
        implicitHeight: 180
        color: "transparent"
        mask: Region {}

        Item {
            anchors.fill: parent
            opacity: root.shouldShowOsd ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: Qt.rgba(0.04, 0.01, 0.1, 0.75)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                Item {
                    id: bottomDeck
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 22

                    Text {
                        anchors.centerIn: parent
                        text: Math.floor(root.nodeVolume * 100)
                        color: root.volColor
                        font {
                            pixelSize: 14
                            family: "monofur Nerd Font"
                            bold: true
                            letterSpacing: 1
                        }
                    }
                }

                Rectangle {
                    id: bar
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: bottomDeck.top
                        leftMargin: 4
                        rightMargin: 4
                        bottomMargin: 0
                    }
                    height: (parent.height - bottomDeck.height - 4) * root.nodeVolume
                    radius: 3
                    color: root.volColor

                    Behavior on height {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }
            }
        }
    }
}
