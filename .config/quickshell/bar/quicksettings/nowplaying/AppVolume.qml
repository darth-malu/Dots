pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.services
import qs.themes

// ═══ PER-APPLICATION AUDIO ═══
// One row per application playback stream (spotify, chrome, discord, ...),
// each with its own mute button + volume slider, reusing the same
// VolumeSlider as the sinks. Nodes come pre-bound from PipewireState.appStreams
// so the PwNodeAudio volume/mute writes actually reach the stream.
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 6

    // applications output to the default (output) sink, so they share the
    // same accent color as the output volume slider for a consistent look
    readonly property color sinkAccent: PipewireState.outputSink !== null ? Themes.accent : Themes.accent2

    // feedback when nothing is playing right now
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        visible: PipewireState.appStreams.length === 0
        color: Qt.rgba(1, 1, 1, 0.04)
        radius: 6

        Text {
            anchors.centerIn: parent
            text: "no application audio"
            color: Themes.muted
            font {
                pixelSize: 9
                family: "Quicksand"
                letterSpacing: 0.5
            }
        }
    }

    Repeater {
        model: PipewireState.appStreams

        delegate: ColumnLayout {
            id: appStreamRow

            required property var modelData

            readonly property PwNode node: modelData

            visible: appStreamRow.node?.audio !== null || false
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: PipewireState.streamDisplayName(appStreamRow.node)
                color: root.sinkAccent
                elide: Text.ElideRight
                font {
                    pixelSize: 10
                    bold: true
                    family: "Quicksand"
                    letterSpacing: 1
                }
            }

            VolumeSlider {
                node: appStreamRow.node
                Layout.fillWidth: true
                glyph: "\uf028"
                glyphMuted: "\uf026"
                accent: root.sinkAccent
            }
        }
    }
}
