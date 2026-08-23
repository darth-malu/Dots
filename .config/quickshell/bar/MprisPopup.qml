import QtQuick.Layouts
import QtQuick
import Quickshell.Widgets
import qs.customItems
import qs.services
import qs.themes
import Quickshell.Services.Mpris
import Quickshell

ColumnLayout {
    id: playersContainer
    anchors.fill: parent
    spacing: 6

    Repeater {
        id: playerRepeater
        model: Mpris.players
        Layout.fillWidth: true

        delegate: Rectangle {
            id: prow

            required property var modelData

            Layout.fillWidth: true
            implicitHeight: 46
            radius: 8

            readonly property bool isAlive: {
                try {
                    return modelData && modelData.identity !== undefined;
                } catch (e) {
                    return false;
                }
            }
            readonly property bool isPlaying: {
                try {
                    return isAlive && modelData.playbackState === MprisPlaybackState.Playing;
                } catch (e) {
                    return false;
                }
            }
            readonly property bool isActive: isAlive && MprisState.player === modelData
            readonly property bool isPaused: {
                try {
                    return isAlive && modelData.playbackState === MprisPlaybackState.Paused;
                } catch (e) {
                    return false;
                }
            }
            readonly property string playerId: {
                try {
                    return isAlive ? (modelData.identity || "Unknown") : "Unknown";
                } catch (e) {
                    return "Unknown";
                }
            }
            readonly property string trackTitle: {
                try {
                    return isAlive ? (modelData.trackTitle || "") : "";
                } catch (e) {
                    return "";
                }
            }
            readonly property bool hasArt: isAlive && (modelData.trackArtUrl ?? "") !== "" && !MprisState.isBrowserPlayer(modelData)
            readonly property bool isBrowser: isAlive && MprisState.isBrowserPlayer(modelData)

            color: rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            // accent rail marks the active (bar-controlled) player
            Rectangle {
                visible: parent.isActive
                anchors.left: parent.left
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                color: "#bd93f9"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 10

                // art thumbnail / note fallback
                ClippingRectangle {
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 6

                    Image {
                        anchors.fill: parent
                        source: prow.hasArt ? prow.modelData.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        mipmap: true
                        visible: prow.hasArt
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !prow.hasArt
                        text: prow.isBrowser ? MprisState.browserGlyph(modelData) : ""
                        color: "#6272a4"
                        font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true

                    Text {
                        text: prow.playerId.toLowerCase()
                        color: prow.isPlaying ? "#50fa7b" : "#6272a4"
                        font {
                            pixelSize: 9
                            bold: true
                            family: "ZedMono Nerd Font"
                            letterSpacing: 1
                        }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: prow.trackTitle.length > 0 ? prow.trackTitle : (prow.isPlaying ? "playing" : "idle")
                        color: prow.trackTitle.length > 0 ? "#f8f8f2" : "#b8bfcb"
                        font {
                            pixelSize: 11
                            bold: true
                            family: "Quicksand"
                        }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // play / pause toggle
                Rectangle {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 13
                    visible: prow.isPlaying || prow.isPaused
                    color: ppHover.containsMouse ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.18) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: prow.isPaused ? "\uf04b" : "\uf04c"
                        color: ppHover.containsMouse ? "#f8f8f2" : (prow.isPaused ? "#bd93f9" : "#50fa7b")
                        font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                    }

                    MouseArea {
                        id: ppHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!prow.isAlive)
                                return;
                            try {
                                if (prow.modelData.canPlay || prow.modelData.canPause)
                                    prow.modelData.togglePlaying();
                            } catch (e) {}
                        }
                    }
                }
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z: -1
                onClicked: {
                    if (!prow.isAlive)
                        return;
                    try {
                        var isMpd = prow.modelData.identity === "Music Player Daemon";
                        if (isMpd)
                            Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "nc"]);
                        else if (prow.modelData.canRaise)
                            prow.modelData.raise();
                    } catch (e) {}
                }
            }
        }
    }
}
