pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.services
import qs.customItems
import qs.themes

Loader {
    id: mprisLoader

    active: MprisState.mprisVisible
    visible: active

    required property var host

    sourceComponent: WrapperMouseArea {
        id: mprisRoot

        // Size tracks the pill so the Loader gets the correct extent
        // width: pill.visible ? pill.width : 0
        // height: pill.visible ? pill.height : 0
        width: 50
        height: 50
        implicitWidth: width
        implicitHeight: height

        hoverEnabled: true
        acceptedButtons: Qt.RightButton | Qt.LeftButton | Qt.MiddleButton | Qt.ForwardButton | Qt.BackButton

        property bool showVolume: false
        property bool showPlaying: MprisState.player?.isPlaying
        property bool showPopup: false

        Timer {
            id: hideVolumeTimer
            interval: 1000
            repeat: false
            running: false
            onTriggered: mprisRoot.showVolume = false
        }

        onExited: {
            hideVolumeTimer.restart();
        }

        onClicked: mouse => {
            mouse.accepted = true;
            if (mouse.button == Qt.LeftButton)
                MprisState.player?.togglePlaying();
            else if (mouse.button == Qt.RightButton)
                MprisState.player?.next();
            else if (mouse.button == Qt.ForwardButton) {
                if (MprisState.player?.identity === "Music Player Daemon")
                    Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "nc"]);
                else {
                    MprisState.player?.raise();
                }
            } else if (mouse.button == Qt.MiddleButton)
                showPopup = !showPopup;
        }

        onWheel: event => {
            if (!MprisState.player?.isPlaying)
                return;

            if (MprisState.player?.volumeSupported) {
                let vol = MprisState.player.volume * 100;
                vol += event.angleDelta.y > 0 ? 4 : -4;
                vol = Math.max(0, Math.min(vol, 100));
                MprisState.player.volume = vol / 100;
                mprisRoot.showVolume = true;
            }
        }

        // ── popup (first child of the wrapper for MarginWrapperManager) ──
        LazyLoader {
            loading: true

            PopupWindow {
                id: popup

                anchor.window: mprisLoader.host
                anchor.rect.x: mprisLoader.host.width / 2 - width / 2
                anchor.rect.y: 35
                visible: mprisRoot.showPopup
                color: 'transparent'
                implicitWidth: Math.min(600, mprisPopupRectangle.implicitWidth + 10)
                implicitHeight: mprisPopupRectangle.implicitHeight + 20

                WrapperRectangle {
                    id: mprisPopupRectangle
                    radius: 6
                    anchors.fill: parent

                    color: Qt.rgba(0.1, 0.04, 0.18, 0.7)
                    border.width: 1
                    border.color: '#A020F0'

                    MprisPopup {}
                }
            }
        }

        // ── pill ──
        Rectangle {
            id: pill
            visible: mprisRoot.showPlaying
            height: mprisLoader.host ? mprisLoader.host.height : 30
            width: pillRow.implicitWidth + 12
            radius: height / 2
            color: Qt.rgba(0.1, 0.04, 0.18, 0.4)

            RowLayout {
                id: pillRow
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 6

                // ── album art + fallback ──
                Item {
                    Layout.preferredWidth: pill.height - 6
                    Layout.preferredHeight: pill.height - 6

                    ClippingWrapperRectangle {
                        id: albumArt
                        visible: MprisState.mprisArtVisible
                        anchors.fill: parent
                        radius: height / 2
                        color: 'transparent'

                        Image {
                            id: albumArtImage
                            anchors.fill: parent
                            source: MprisState.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    // fallback when no art
                    BarText {
                        anchors.centerIn: parent
                        visible: !albumArt.visible
                        text: "🎵"
                        pointSize: 10
                    }
                }

                // ── track title ──
                BarText {
                    id: title
                    renderNative: true
                    Layout.alignment: Qt.AlignVCenter
                    text: {
                        let strLength = 30;
                        var str = MprisState.player?.trackTitle || "Unknown Track";
                        return str.length > strLength ? str.slice(0, strLength) + '..' : str;
                    }
                    color: Themes.mprisTextColor
                    font: Themes.quicksand_medium
                }

                // ── active player name ──
                BarText {
                    id: playerId
                    text: "· " + (MprisState.player?.identity || "")
                    color: Themes.toxicGreen
                    font: Themes.quicksand_medium
                    visible: Mpris.players.length > 1
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var players = [];
                            for (let p of Mpris.players.values)
                                players.push(p);
                            if (players.length > 1) {
                                var idx = players.indexOf(MprisState.player);
                                if (idx >= 0)
                                    MprisState.player = players[(idx + 1) % players.length];
                                else
                                    MprisState.player = players[0];
                            }
                        }
                    }
                }

                // ── volume readout ──
                BarText {
                    id: volumePlayer
                    visible: mprisRoot.showVolume
                    text: MprisState.player ? " 🔊 " + Math.round(MprisState.player.volume * 100) : ""
                    font: title.font
                    color: Themes.mprisVolumeColor
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                // ── play/pause button with progress ring ──
                Item {
                    id: playButtonBox
                    implicitWidth: 22
                    implicitHeight: 22
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22

                    Canvas {
                        id: progressRing
                        anchors.fill: parent
                        anchors.margins: 1.5
                        antialiasing: true

                        property real progress: 0

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var cx = width / 2;
                            var cy = height / 2;
                            var r = Math.min(cx, cy) - 1.5;

                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.strokeStyle = Qt.rgba(1, 0.71, 0.76, 0.25);
                            ctx.lineWidth = 2.5;
                            ctx.stroke();

                            if (progressRing.progress > 0.005) {
                                ctx.beginPath();
                                var startAngle = -Math.PI / 2;
                                var endAngle = startAngle + Math.PI * 2 * Math.min(progressRing.progress, 1);
                                ctx.arc(cx, cy, r, startAngle, endAngle);
                                ctx.strokeStyle = "#FF7EB3";
                                ctx.lineWidth = 2.5;
                                ctx.stroke();
                            }
                        }

                        Timer {
                            id: progressTimer
                            interval: 200
                            repeat: true
                            running: MprisState.player?.isPlaying ?? false
                            onTriggered: {
                                var p = MprisState.player;
                                if (p && p.length > 0) {
                                    progressRing.progress = p.position / p.length;
                                } else {
                                    progressRing.progress = 0;
                                }
                                progressRing.requestPaint();
                            }
                        }
                    }

                    BarText {
                        anchors.centerIn: parent
                        text: MprisState.player?.isPlaying ? "⏸" : "▶"
                        baseColor: "#FF7EB3"
                        color: "#FF7EB3"
                        pointSize: 9
                        paddingg: 0
                    }
                }
            }
        }
    }
}
