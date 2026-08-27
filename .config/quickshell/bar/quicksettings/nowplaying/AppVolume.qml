pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.services

// ═══ PER-APPLICATION AUDIO ═══
// One row per audio output stream (spotify, chrome, ...) — each with its own
// mute button + volume slider, reusing the same VolumeSlider as the sinks.
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 6

    Repeater {
        model: Pipewire.nodes

        delegate: ColumnLayout {
            id: appStreamRow

            required property var modelData

            readonly property bool appStream: PipewireState.isOutputApplicationStream(modelData)
            // avoid touching mixer state for nodes that are not app streams
            readonly property PwNode node: appStream ? modelData : null

            visible: appStream && (node?.audio ?? null) !== null
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
