import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import qs.themes

ColumnLayout {
    required property PwNode node;

    PwObjectTracker { objects: [ node ] }

    RowLayout {
        spacing: 8

        Image {
            visible: source != ""
            source: {
                const icon = node.properties["application.icon-name"] ?? "audio-volume-high-symbolic";
                return `image://icon/${icon}`;
            }
            sourceSize.width: 20
            sourceSize.height: 20
        }

        Label {
            Layout.fillWidth: true
            text: {
                const app = node.properties["application.name"] ?? (node.description != "" ? node.description : node.name);
                const media = node.properties["media.name"];
                return media != undefined ? `${app} - ${media}` : app;
            }
            color: "#cdd6f4"
            font {
                pixelSize: 11
                family: "Quicksand"
            }
            elide: Text.ElideRight
        }

        Button {
            id: muteBtn
            text: node.audio.muted ? "unmute" : "mute"
            onClicked: node.audio.muted = !node.audio.muted

            background: Rectangle {
                radius: 6
                color: muteBtn.hovered
                    ? (node.audio.muted ? Qt.lighter("#a6e3a1", 1.1) : Qt.lighter("#585b70", 1.1))
                    : (node.audio.muted ? "#a6e3a1" : "#585b70")
                implicitWidth: muteBtn.implicitWidth + 16
                implicitHeight: 24

                Behavior on color { ColorAnimation { duration: 100 } }
            }

            contentItem: Text {
                text: muteBtn.text
                color: node.audio.muted ? "#1e1e2e" : "#cdd6f4"
                font {
                    pixelSize: 10
                    bold: true
                    family: "Quicksand"
                }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    RowLayout {
        spacing: 8

        Label {
            Layout.preferredWidth: 50
            text: `${Math.floor(node.audio.volume * 100)}%`
            color: "#a6adc8"
            font {
                pixelSize: 10
                family: "ZedMono Nerd Font"
                bold: true
            }
        }

        Slider {
            id: volSlider
            Layout.fillWidth: true
            value: node.audio.volume
            onValueChanged: node.audio.volume = value

            background: Rectangle {
                x: volSlider.leftPadding
                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                width: volSlider.availableWidth
                height: 4
                radius: 2
                color: "#313244"

                Rectangle {
                    width: volSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: node.audio.muted ? "#585b70" : "#c6a0f6"
                }
            }

            handle: Rectangle {
                x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                width: 12
                height: 12
                radius: 6
                color: node.audio.muted ? "#585b70" : "#c6a0f6"
                border.color: "#1e1e2e"
                border.width: 2
            }
        }
    }
}
