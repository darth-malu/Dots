pragma ComponentBehavior: Bound

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

    // players currently playing float to the top so they are one glance away
    readonly property var sortedPlayers: {
        const all = [...Mpris.players.values];
        all.sort((a, b) => {
            const pa = a.playbackState === MprisPlaybackState.Playing ? 0 : 1;
            const pb = b.playbackState === MprisPlaybackState.Playing ? 0 : 1;
            return pa - pb;
        });
        return all;
    }

    // shared 1s tick keeps every visible progress line honest without
    // each row owning its own timer
    property int progressTick: 0

    Timer {
        interval: 1000
        repeat: true
        running: playersContainer.sortedPlayers.some(p => p.isPlaying)
        onTriggered: playersContainer.progressTick++
    }

    Repeater {
        id: playerRepeater
        model: playersContainer.sortedPlayers
        Layout.fillWidth: true

        delegate: Rectangle {
            id: prow

            required property var modelData

            Layout.fillWidth: true
            implicitHeight: 52
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
            readonly property bool isPinned: isAlive && MprisState.pinPlayerName === modelData.dbusName
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

            // 0..1 playback progress for the thin line under the row
            readonly property real progress: {
                playersContainer.progressTick;
                if (!isAlive)
                    return 0;
                const len = modelData.length;
                const pos = modelData.position;
                if (!len || len <= 0 || pos == null || isNaN(pos))
                    return 0;
                return Math.min(pos / len, 1);
            }

            color: rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 10

                // art thumbnail / note fallback
                ClippingRectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 7
                    // dark tile behind browser glyphs so they read as icons, not art
                    color: prow.isBrowser ? Themes.cardBg : "transparent"

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
                        text: prow.isBrowser ? MprisState.browserGlyph(modelData) : "\uf001"
                        color: Themes.muted
                        font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: prow.playerId.toLowerCase()
                            color: prow.isPlaying ? "#50fa7b" : Themes.muted
                            font {
                                pixelSize: 9
                                bold: true
                                family: "ZedMono Nerd Font"
                                letterSpacing: 1
                            }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // pin marker — this player drives the quicksettings card
                        Text {
                            visible: prow.isPinned
                            text: "\uf08d"
                            color: "#f1fa8c"
                            font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                        }
                    }

                    Text {
                        text: prow.trackTitle.length > 0 ? prow.trackTitle : (prow.isPlaying ? "playing" : "idle")
                        color: prow.trackTitle.length > 0 ? Themes.fg : Themes.dim
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

                // previous · play/pause · next cluster
                RowLayout {
                    spacing: 2

                    Text {
                        visible: prow.isAlive
                        text: "\uf048"
                        color: prevHover.containsMouse ? Themes.fg : Themes.muted
                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }

                        MouseArea {
                            id: prevHover
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (prow.isAlive)
                                    try { prow.modelData.previous(); } catch (e) {}
                            }
                        }
                    }

                    // play / pause toggle
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        visible: prow.isPlaying || prow.isPaused
                        color: ppHover.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.18) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: prow.isPaused ? "\uf04b" : "\uf04c"
                            color: ppHover.containsMouse ? Themes.fg : (prow.isPaused ? Themes.accent : "#50fa7b")
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

                    Text {
                        visible: prow.isAlive
                        text: "\uf050"
                        color: nextHover.containsMouse ? Themes.fg : Themes.muted
                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }

                        MouseArea {
                            id: nextHover
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (prow.isAlive)
                                    try { prow.modelData.next(); } catch (e) {}
                            }
                        }
                    }
                }
            }

            // thin progress line hugging the row's bottom edge
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: 2
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.07)
                visible: prow.progress > 0

                Rectangle {
                    width: parent.width * prow.progress
                    height: parent.height
                    radius: height / 2
                    color: prow.isPlaying ? "#50fa7b" : Themes.accent

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.Linear }
                    }
                }
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                z: -1
                onClicked: mouse => {
                    if (!prow.isAlive)
                        return;
                    // middle-click pins the player to the quicksettings card
                    if (mouse.button === Qt.MiddleButton) {
                        MprisState.pinPlayerName = MprisState.pinPlayerName === prow.modelData.dbusName ? "" : prow.modelData.dbusName;
                        return;
                    }
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

    // footer hint for the hidden interactions
    Text {
        Layout.alignment: Qt.AlignHCenter
        visible: playersContainer.sortedPlayers.length > 0
        text: "click raises · middle-click pins to card"
        color: Themes.muted
        font {
            pixelSize: 8
            family: "Quicksand"
            letterSpacing: 0.5
        }
    }
}
