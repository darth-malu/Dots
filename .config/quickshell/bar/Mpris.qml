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

    // FIX 1: Force the Loader to take on the dimensions of whatever it loads
    // width: item ? item.width : 0
    // height: item ? item.height : 0

    width: 20
    height: 20

    sourceComponent: WrapperMouseArea {
        id: mprisRoot

        // FIX 2: Define size cleanly from the inside visual element
        width: pill.visible ? pill.width : 0
        height: pill.visible ? pill.height : 0

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

        Rectangle {
            id: pill
            visible: mprisRoot.showPlaying

            // FIX 3: Ensure explicit height comes safely from the panel host
            height: mprisLoader.host ? mprisLoader.host.height : 30
            width: pillRow.implicitWidth + 12 // Added slight padding safety
            radius: height / 2
            color: Qt.rgba(0.1, 0.04, 0.18, 0.4)

            RowLayout {
                id: pillRow
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 6

                Item {
                    id: playButtonBox
                    implicitWidth: 22
                    implicitHeight: 22
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22

                    Canvas {
                        id: progressRing
                        anchors.fill: parent
                        anchors.margins: 2
                        antialiasing: true

                        property real progress: 0

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var cx = width / 2;
                            var cy = height / 2;
                            var r = Math.min(cx, cy) - 1;

                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15);
                            ctx.lineWidth = 2;
                            ctx.stroke();

                            if (progressRing.progress > 0.005) {
                                ctx.beginPath();
                                var startAngle = -Math.PI / 2;
                                var endAngle = startAngle + Math.PI * 2 * Math.min(progressRing.progress, 1);
                                ctx.arc(cx, cy, r, startAngle, endAngle);
                                ctx.strokeStyle = "#88FF00";
                                ctx.lineWidth = 2;
                                ctx.stroke();
                            }
                        }
                    }

                    BarText {
                        anchors.centerIn: parent
                        text: MprisState.player?.isPlaying ? "⏸" : "▶"
                        baseColor: "#88FF00"
                        color: "#88FF00"
                        pointSize: 9
                        paddingg: 0
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

                ClippingWrapperRectangle {
                    id: albumArt
                    visible: MprisState.mprisArtVisible
                    radius: height / 2

                    // FIX 4: Use clear, hard structural layout properties instead of parent.parent chains
                    Layout.preferredWidth: pill.height - 6
                    Layout.preferredHeight: pill.height - 6
                    color: 'transparent'

                    Image {
                        id: albumArtImage
                        anchors.fill: parent
                        source: MprisState.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop // Crop looks better in circular frames than Fit
                        asynchronous: true
                    }
                }

                BarText {
                    id: title
                    renderNative: true
                    Layout.alignment: Qt.AlignVCenter
                    text: {
                        let strLength = 30; // Dropped to 30 to prevent bar overflowing on smaller layouts
                        var str = MprisState.player?.trackTitle || "Unknown Track";
                        return str.length > strLength ? str.slice(0, strLength) + '..' : str;
                    }
                    color: Themes.mprisTextColor
                    font: Themes.quicksand_medium
                }

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

                BarText {
                    id: volumePlayer
                    visible: mprisRoot.showVolume
                    text: MprisState.player ? " 🔊 " + Math.round(MprisState.player.volume * 100) : ""
                    font: title.font
                    color: Themes.mprisVolumeColor
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
