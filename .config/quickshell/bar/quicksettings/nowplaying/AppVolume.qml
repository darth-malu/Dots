pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.services

// ═══ PER-APPLICATION AUDIO ═══
// One row per application playback stream (spotify, chrome, discord, ...),
// each with its own mute button + volume slider, reusing the same
// VolumeSlider as the sinks. Nodes come pre-bound from PipewireState.appStreams
// so the PwNodeAudio volume/mute writes actually reach the stream.
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 6

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
                color: "#8be9fd"
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
                accent: "#8be9fd"
            }
        }
    }
}
