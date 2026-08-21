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

            readonly property bool isAlive: {
                try { return modelData && modelData.identity !== undefined; }
                catch(e) { return false; }
            }
            readonly property bool isPlaying: {
                try { return isAlive && modelData.playbackState === MprisPlaybackState.Playing; }
                catch(e) { return false; }
            }
            readonly property string playerId: {
                try { return isAlive ? (modelData.identity || "Unknown") : "Unknown"; }
                catch(e) { return "Unknown"; }
            }
            readonly property string trackTitle: {
                try { return isAlive ? (modelData.trackTitle || "") : ""; }
                catch(e) { return ""; }
            }

            Behavior on color { ColorAnimation { duration: 80 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Rectangle {
                    implicitWidth: 6; implicitHeight: 6; radius: 3
                    color: parent.parent.isPlaying ? "#88FF00" : "#6272a4"
                }

                Text {
                    text: parent.parent.playerId
                    color: parent.parent.isPlaying ? "#88FF00" : "#f8f8f2"
                    font { pixelSize: 11; bold: true; family: "Quicksand" }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: parent.parent.trackTitle
                    color: "#b8bfcb"
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
                    if (!isAlive) return;
                    try {
                        var isMpd = modelData.identity === "Music Player Daemon";
                        if (isMpd)
                            Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "nc"]);
                        else if (modelData.canRaise)
                            modelData.raise();
                    } catch(e) {}
                }
            }
        }
    }
}
