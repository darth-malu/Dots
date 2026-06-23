import QtQuick.Layouts
import QtQuick
import qs.customItems
import qs.themes
import Quickshell.Services.Mpris
import Quickshell

ColumnLayout {
    id: playersContainer
    anchors.fill: parent
    spacing: 4

    Repeater {
        id: playerRepeater
        model: Mpris.players
        Layout.fillWidth: true

        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 32
            radius: 6
            color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            Behavior on color { ColorAnimation { duration: 80 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Rectangle {
                    implicitWidth: 6; implicitHeight: 6; radius: 3
                    color: modelData.playbackState === MprisPlaybackState.Playing ? "#88FF00" : "#585b70"
                }

                Text {
                    text: modelData.identity
                    color: modelData.playbackState === MprisPlaybackState.Playing ? "#88FF00" : "#cdd6f4"
                    font { pixelSize: 11; bold: true; family: "Quicksand" }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: modelData.trackTitle || ""
                    color: "#a6adc8"
                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                    elide: Text.ElideRight
                    Layout.preferredWidth: 120
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var isMpd = modelData.identity === "Music Player Daemon";
                    if (isMpd)
                        Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "nc"]);
                    if (modelData.canRaise)
                        modelData.raise();
                }
            }
        }
    }
}
