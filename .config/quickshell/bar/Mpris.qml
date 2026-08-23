pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.services
import qs.customItems
import qs.themes

Item {
    id: mprisRoot

    required property var host

    width: mprisRoot.pillVisible ? pill.implicitWidth : 0
    height: mprisRoot.pillVisible ? pill.implicitHeight : 0
    implicitWidth: width
    implicitHeight: height

    visible: MprisState.mprisVisible

    property bool showVolume: false
    property bool showPlaying: MprisState.player?.isPlaying ?? false
    property bool showPopup: false
    property bool showArtPopup: false
    readonly property bool pillVisible: MprisState.hideWhenIdle ? showPlaying : (MprisState.player !== null)

    Timer {
        id: hideVolumeTimer
        interval: 1000
        repeat: false
        running: false
        onTriggered: mprisRoot.showVolume = false
    }

    WrapperMouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.RightButton | Qt.LeftButton | Qt.MiddleButton | Qt.ForwardButton | Qt.BackButton

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
                mprisRoot.showPopup = !mprisRoot.showPopup;
        }

        onWheel: event => {
            if (!(MprisState.player?.isPlaying ?? false))
                return;

            if (MprisState.player?.volumeSupported) {
                let vol = MprisState.player.volume * 100;
                vol += event.angleDelta.y > 0 ? 4 : -4;
                vol = Math.max(0, Math.min(vol, 100));
                MprisState.player.volume = vol / 100;
                mprisRoot.showVolume = true;
                hideVolumeTimer.restart();
            }
        }

        // ── pill ──
        Rectangle {
            id: pill
            visible: mprisRoot.pillVisible
            implicitHeight: mprisRoot.host ? mprisRoot.host.height : 30
            implicitWidth: pillRow.implicitWidth + 12
            radius: height / 2
            // color: Qt.rgba(0.1, 0.04, 0.18, 0.4)
            color: "transparent"

            RowLayout {
                id: pillRow
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 6

                // ── album art + fallback ──
                Item {
                    Layout.preferredWidth: pill.height - 4
                    Layout.preferredHeight: pill.height - 4

                    // ClippingRectangle (not ClippingWrapperRectangle) — the wrapper
                    // variant manages child geometry and breaks anchored images
                    ClippingRectangle {
                        id: albumArt
                        visible: MprisState.mprisArtVisible
                        anchors.fill: parent
                        radius: height / 2
                        color: 'transparent'

                        Image {
                            id: albumArtImage
                            anchors.fill: parent
                            source: MprisState.artFor(MprisState.player)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: MprisState.mprisArtVisible
                        }

                        // browsers never get art — show their icon instead
                        Text {
                            anchors.centerIn: parent
                            visible: MprisState.isBrowserPlayer(MprisState.player)
                            text: MprisState.browserGlyph(MprisState.player)
                            color: "#bd93f9"
                            font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                        }
                    }

                    // fallback when no art
                    BarText {
                        anchors.centerIn: parent
                        // visible: !albumArt.visible
                        visible: !(albumArtImage.status == Image.Ready) && !MprisState.isBrowserPlayer(MprisState.player)
                        text: "🎵"
                        pointSize: 10
                    }

                    // left-click art → toggle art popup (other buttons pass through to pill)
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mprisRoot.showArtPopup = !mprisRoot.showArtPopup
                    }
                }

                // ── track title (marquee-scrolls when it doesn't fit) ──
                MarqueeText {
                    id: title
                    Layout.alignment: Qt.AlignVCenter
                    maxWidth: 150
                    scrolling: MprisState.marqueeEnabled
                    text: MprisState.player?.trackTitle || "Unknown Track"
                    textColor: Themes.mprisTextColor
                    fontFamily: "quicksand"
                    fontBold: true
                    pixelSize: 12
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

                Item {
                    Layout.fillWidth: true
                }

                // ── play/pause button with progress ring ──
                // hiding the progress pill hides the pause button with it
                Item {
                    id: playButtonBox
                    visible: MprisState.showMprisProgress
                    Layout.preferredWidth: visible ? 22 : 0
                    Layout.preferredHeight: visible ? 22 : 0

                    Canvas {
                        id: progressRing
                        anchors.fill: parent
                        anchors.margins: 2
                        antialiasing: true
                        visible: MprisState.showMprisProgress || mprisRoot.showVolume

                        property real progress: 0

                        onProgressChanged: requestPaint()
                        onVisibleChanged: requestPaint()

                        function updateProgress() {
                            var p = MprisState.player;
                            if (!p || !(p.length > 0)) {
                                progress = 0;
                                return;
                            }
                            var pos = Math.max(0, Math.min(p.position ?? 0, p.length));
                            progress = pos / p.length;
                        }

                        Connections {
                            target: mprisRoot
                            function onShowVolumeChanged() {
                                progressRing.requestPaint();
                            }
                        }

                        Connections {
                            target: MprisState.player
                            function onVolumeChanged() {
                                if (mprisRoot.showVolume)
                                    progressRing.requestPaint();
                            }
                            // live position/length tracking keeps the ring honest
                            // across seeks and track changes (timer is just a fallback)
                            function onPositionChanged() {
                                progressRing.updateProgress();
                            }
                            function onLengthChanged() {
                                progressRing.updateProgress();
                            }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var cx = width / 2;
                            var cy = height / 2;
                            var r = Math.min(cx, cy) - 1.5;

                            var frac;
                            if (mprisRoot.showVolume)
                                frac = Math.max(0, Math.min(MprisState.player?.volume ?? 0, 1));
                            else
                                frac = progressRing.progress;

                            // dim track
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.strokeStyle = Qt.rgba(1, 0.71, 0.76, 0.25);
                            ctx.lineWidth = 2.5;
                            ctx.stroke();

                            if (frac > 0.004) {
                                var startAngle = -Math.PI / 2;
                                var full = frac >= 0.9985;
                                ctx.beginPath();
                                if (full) {
                                    // complete circle avoids a round-cap nub at 12 o'clock
                                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                    ctx.lineCap = "butt";
                                } else {
                                    ctx.arc(cx, cy, r, startAngle, startAngle + Math.PI * 2 * frac);
                                    ctx.lineCap = "round";
                                }
                                ctx.strokeStyle = mprisRoot.showVolume ? "#bd93f9" : "#FF7EB3";
                                ctx.lineWidth = 2.5;
                                ctx.stroke();
                            }
                        }

                        Timer {
                            id: progressTimer
                            interval: 200
                            repeat: true
                            running: MprisState.player?.isPlaying ?? false
                            onTriggered: progressRing.updateProgress()
                        }
                    }

                    // crisp speaker/mute glyph over the canvas waves
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -3
                        visible: mprisRoot.showVolume
                        text: {
                            var v = Math.max(0, Math.min(MprisState.player?.volume ?? 0, 1));
                            return v <= 0.001 ? "\uf026" : "\uf028";
                        }
                        color: (MprisState.player?.volume ?? 0) <= 0.001 ? "#6272a4" : "#FF7EB3"
                        font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
                    }

                    BarText {
                        anchors.centerIn: parent
                        // play/pause glyph hides while the volume speaker takes over
                        visible: !mprisRoot.showVolume
                        symbolText: MprisState.player?.isPlaying ? "\uf04c" : "\uf04b"
                        baseColor: "#FF7EB3"
                        color: "#FF7EB3"
                        pointSize: 7
                        symbolSize: 7
                        paddingg: 0
                    }
                }
            }
        }
    }

    // ── popup (lives outside the mouse area, never destroyed by Loader) ──
    LazyLoader {
        loading: true

        PopupWindow {
            id: popup

            // anchor.window: mprisRoot.host
            // anchor.rect.x: mprisRoot.host.width / 2 - width / 2
            // anchor.rect.y: 35
            anchor.window: mprisRoot.host
            anchor.rect.x: mprisRoot.host.width / 2 - width / 2
            anchor.rect.y: 35
            visible: mprisRoot.showPopup
            grabFocus: true
            color: MiscState.popupSolidBg ? "#282a36" : "transparent"
            implicitWidth: 280
            implicitHeight: Math.min(mprisPopupContent.implicitHeight + 16, 320)

            Rectangle {
                id: mprisPopupRect
                anchors.fill: parent
                radius: 10
                color: "#282a36"
                border.width: 1
                border.color: "#44475a"

                Shortcut {
                    sequence: "Escape"
                    onActivated: mprisRoot.showPopup = false
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mprisRoot.showPopup = false
                    z: -1
                }

                MprisPopup {
                    id: mprisPopupContent
                    anchors.fill: parent
                    anchors.margins: 8
                }
            }
        }
    }

    // ── album art popup (opened by clicking the art in the pill) ──
    LazyLoader {
        loading: true

        PopupWindow {
            id: artPopup

            anchor.window: mprisRoot.host
            anchor.rect.x: {
                let g = mprisRoot.mapToGlobal(0, 0);
                return g.x + mprisRoot.width / 2 - width / 2;
            }
            anchor.rect.y: 35
            visible: mprisRoot.showArtPopup && MprisState.player !== null
            grabFocus: true
            color: MiscState.popupSolidBg ? "#282a36" : "transparent"
            implicitWidth: 280
            implicitHeight: 280

            Rectangle {
                id: artPopupRect
                anchors.fill: parent
                radius: 12
                color: "#282a36"
                border.width: 1
                border.color: "#44475a"

                Shortcut {
                    sequence: "Escape"
                    onActivated: mprisRoot.showArtPopup = false
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mprisRoot.showArtPopup = false
                    z: -1
                }

                // album art fills the popup (respects the settings toggle)
                Image {
                    anchors.fill: parent
                    source: MprisState.artFor(MprisState.player)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    mipmap: true
                    visible: MprisState.mprisArtVisible && status === Image.Ready
                }

                // browsers never get art — show their icon instead
                Text {
                    anchors.centerIn: parent
                    visible: !MprisState.mprisArtVisible || MprisState.isBrowserPlayer(MprisState.player)
                    text: MprisState.isBrowserPlayer(MprisState.player) ? MprisState.browserGlyph(MprisState.player) : "🎵"
                    color: "#bd93f9"
                    font { pixelSize: 42; family: "Symbols Nerd Font Mono" }
                }

                // fallback when no art
                BarText {
                    anchors.centerIn: parent
                    visible: !(MprisState.player?.trackArtUrl ?? "") && !MprisState.isBrowserPlayer(MprisState.player)
                    text: "🎵"
                    pointSize: 48
                }
            }
        }
    }
}
