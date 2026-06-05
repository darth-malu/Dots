import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.themes

ShellRoot {
    FloatingWindow {
        color: contentItem.palette.active.window

        implicitWidth: 320
        implicitHeight: Math.min(mixerCol.implicitHeight + 24, 500)

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#1e1e2e"
            border.color: "#45475a"

            ScrollView {
                anchors.fill: parent
                anchors.margins: 12
                contentWidth: availableWidth

                ColumnLayout {
                    id: mixerCol
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "  Audio Mixer"
                        color: "#c6a0f6"
                        font {
                            pixelSize: 12
                            bold: true
                            family: "Quicksand"
                            letterSpacing: 1
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#313244"
                    }

                    PwNodeLinkTracker {
                        id: linkTracker
                        node: Pipewire.defaultAudioSink
                    }

                    MixerEntry {
                        node: Pipewire.defaultAudioSink
                        Layout.bottomMargin: 4
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        color: "#313244"
                        implicitHeight: 1
                    }

                    Repeater {
                        model: linkTracker.linkGroups

                        MixerEntry {
                            required property PwLinkGroup modelData
                            node: modelData.source
                        }
                    }
                }
            }
        }
    }
}
