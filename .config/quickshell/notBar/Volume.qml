pragma ComponentBehavior: Bound
// allows using outer component ids root.currentVolume
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.themes

Scope {
    id: root
    property bool shouldShowOsd: false
    property var defaultSink: Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource
    property var ifAudioNode: defaultSink?.audio // extra info if node sends/receives audio, if non-null node manages audio
    property var currentVolume: ifAudioNode?.volume

    // Bind the pipewire node so its properties eg.volume will be tracked
    PwObjectTracker {
        objects: [root.defaultSink, root.defaultSource]
    }

    Connections {
        target: root.ifAudioNode ?? null // NOTE: patch work

        function onVolumeChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.shouldShowOsd = false
    }

    LazyLoader {
        active: root.shouldShowOsd
        // loading: true

        // PanelWindow.visible could be set instead of using a loader, but using a loader will reduce the memory overhead when the window isn't open.
        PanelWindow {
            // Since the panel's screen is unset, it will be picked by the compositor when the window is created. Most compositors pick the current active monitor.
            anchors.right: true
            margins.right: screen.width / 95
            exclusiveZone: 0

            implicitWidth: 35
            implicitHeight: 240
            color: "transparent"

            // An empty click mask prevents the window from blocking mouse events.
            mask: Region {}

            Rectangle {
                id: outerRectangle
                implicitWidth: parent.width
                implicitHeight: parent.height
                radius: 4
                color: "#80000000"
                // clip: true

                // opacity: root.shouldShowOsd ? 1.0 : 0.0
                // Behavior on opacity {
                //     NumberAnimation {
                //         duration: 200
                //     }
                // }

                Rectangle {
                    id: innerCurrentVolumeRectangle
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 3
                    }
                    implicitHeight: (parent.height - 6) * (root.currentVolume ?? 0)
                    radius: parent.radius
                    color: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1.00) // '#bd93f9'
                }

                Text {
                    id: currentVolumeText
                    visible: true
                    text: Math.floor(root.currentVolume * 100)
                    color: 'black'
                    anchors {
                        centerIn: parent
                    }
                    // leftPadding: 15
                    // rightPadding: 15
                    font: Themes.quicksand
                }
            }
        }
    }
}
