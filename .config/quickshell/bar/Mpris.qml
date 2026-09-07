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

    width: mprisRoot.pillVisible ? pill.implicitWidth : idleVolumeSpot.width
    height: mprisRoot.pillVisible ? pill.implicitHeight : idleVolumeSpot.height
    implicitWidth: width
    implicitHeight: height

    visible: MiscState.showMpris && MprisState.mprisVisible

    // closing the module must never leave its popups orphaned
    onVisibleChanged: {
        if (!visible) {
            showPopup = false;
            showArtPopup = false;
            showVolume = false;
        }
    }

    property bool showVolume: false
    property bool showPlaying: MprisState.player?.isPlaying ?? false
    property bool showPopup: false
    property bool showArtPopup: false
    property bool _hovering: false
    readonly property bool pillVisible: MprisState.hideWhenIdle ? showPlaying : (MprisState.player !== null)

    // compact pills show only the ring/icon; hovering expands the full layout
    // (the default view is a settings option)
    readonly property bool showDetails: !MprisState.mprisCompact || mprisRoot._hovering

    // survives across the pill's show/hide so timers keep working
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

        onEntered: {
            mprisRoot._hovering = true;
        }

        onExited: {
            mprisRoot._hovering = false;
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
                    HyprlandService.dispatch('hl.dsp.workspace.toggle_special("nc")');
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

        // ── the wrapper's ONE managed child — extra visual children get
        // unparented from the scene, so spot + pill must live in here.
        // never anchored/sized by hand: MarginWrapperManager owns its geometry ──
        Item {
            id: content

            // ── hidden-pill volume spot ──
            // when the pill is tucked away (hide when idle), scrolling its old
            // slot still adjusts volume — the ring + speaker flash on during the
            // scroll and fade out shortly after it stops
            Item {
                id: idleVolumeSpot

                visible: !mprisRoot.pillVisible && MprisState.player !== null
                implicitWidth: visible ? 26 : 0
                implicitHeight: mprisRoot.host ? mprisRoot.host.height : 30

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: false

                    onWheel: event => {
                        const p = MprisState.player;
                        if (!p || !p.volumeSupported)
                            return;
                        let vol = p.volume * 100;
                        vol += event.angleDelta.y > 0 ? 4 : -4;
                        vol = Math.max(0, Math.min(vol, 100));
                        p.volume = vol / 100;
                        mprisRoot.showVolume = true;
                        hideVolumeTimer.restart();
                    }
                }

                Canvas {
                    id: idleVolRing
                    anchors.fill: parent
                    anchors.margins: 2
                    antialiasing: true
                    visible: mprisRoot.showVolume

                    onVisibleChanged: requestPaint()

                    Connections {
                        target: mprisRoot
                        function onShowVolumeChanged() {
                            idleVolRing.requestPaint();
                        }
                    }

                    Connections {
                        target: MprisState.player
                        function onVolumeChanged() {
                            if (mprisRoot.showVolume)
                                idleVolRing.requestPaint();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        // zero-sized slot (hidden pill) would make arc() throw
                        if (width <= 4 || height <= 4)
                            return;

                        var frac = Math.max(0, Math.min(MprisState.player?.volume ?? 0, 1));
                        var r = Math.min(width, height) / 2 - 1.5;

                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                        ctx.strokeStyle = Qt.rgba(1, 0.71, 0.76, 0.25);
                        ctx.lineWidth = 2.5;
                        ctx.stroke();

                        if (frac > 0.004) {
                            ctx.beginPath();
                            var full = frac >= 0.9985;
                            if (full) {
                                ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                                ctx.lineCap = "butt";
                            } else {
                                ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac);
                                ctx.lineCap = "round";
                            }
                            ctx.strokeStyle = Themes.accent;
                            ctx.lineWidth = 2.5;
                            ctx.stroke();
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: mprisRoot.showVolume
                    text: {
                        var v = Math.max(0, Math.min(MprisState.player?.volume ?? 0, 1));
                        return v <= 0.001 ? "\uf026" : "\uf028";
                    }
                    color: (MprisState.player?.volume ?? 0) <= 0.001 ? Themes.muted : Themes.pink
                    font {
                        pixelSize: 9
                        family: "Symbols Nerd Font Mono"
                    }
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
                    // hidden detail items still reserve their grid gap — collapse it
                    spacing: mprisRoot.showDetails ? 6 : 0

                    // ── album art + fallback ──
                    Item {
                        visible: mprisRoot.showDetails
                        Layout.preferredWidth: visible ? pill.height - 4 : 0
                        Layout.preferredHeight: visible ? pill.height - 4 : 0

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
                                color: Themes.accent
                                font {
                                    pixelSize: 13
                                    family: "Symbols Nerd Font Mono"
                                }
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

                        // left-click art → open art popup (re-click keeps it open)
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!mprisRoot.showArtPopup) mprisRoot.showArtPopup = true
                        }
                    }

                    // ── track title (marquee-scrolls when it doesn't fit) ──
                    MarqueeText {
                        id: title
                        visible: mprisRoot.showDetails
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
                        visible: Mpris.players.length > 1 && mprisRoot.showDetails
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
                        visible: mprisRoot.showDetails
                        Layout.fillWidth: true
                    }

                    // ── player icon button with progress ring ──
                    // the ring is thin; the center shows the APP's glyph (not a
                    // play/pause symbol) — status lives in the ring/icon colours
                    Item {
                        id: playButtonBox
                        visible: MprisState.showMprisProgress
                        Layout.preferredWidth: visible ? 26 : 0
                        Layout.preferredHeight: visible ? 26 : 0

                        // solid disc behind ring + glyph so it reads over any art
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: width / 2
                            color: Qt.rgba(0, 0, 0, 0.28)
                        }

                        Canvas {
                            id: progressRing
                            anchors.fill: parent
                            anchors.margins: 2
                            antialiasing: true
                            visible: MprisState.showMprisProgress || mprisRoot.showVolume

                            property real progress: 0

                            // restart-watchdog state — some players forget to
                            // re-report Position/Seeked when the same track
                            // restarts, leaving the ring pinned near-full. shared
                            // progress machinery lives in MprisState.progress()
                            property var _pstate: MprisState.progressState()

                            onProgressChanged: requestPaint()
                            onVisibleChanged: requestPaint()

                            function updateProgress() {
                                progress = MprisState.progress(MprisState.player, _pstate, MprisState.player?.isPlaying ?? false);
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

                                // zero-sized slot would make arc() throw
                                if (r <= 0)
                                    return;

                                var frac;
                                if (mprisRoot.showVolume)
                                    frac = Math.max(0, Math.min(MprisState.player?.volume ?? 0, 1));
                                else
                                    frac = progressRing.progress;

                                // dim track
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                ctx.strokeStyle = Qt.rgba(1, 0.71, 0.76, 0.18);
                                ctx.lineWidth = 1.5;
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
                                    // playing = full pink, paused = faded — status hints
                                    const playing = MprisState.player?.isPlaying ?? false;
                                    ctx.strokeStyle = mprisRoot.showVolume ? Themes.accent
                                        : (playing ? Themes.pink : Qt.rgba(Themes.pink.r, Themes.pink.g, Themes.pink.b, 0.45));
                                    ctx.lineWidth = 1.5;
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

                        // crisp speaker/mute glyph centered over the ring
                        Text {
                            anchors.centerIn: parent
                            visible: mprisRoot.showVolume
                            text: {
                                var v = Math.max(0, Math.min(MprisState.player?.volume ?? 0, 1));
                                return v <= 0.001 ? "\uf026" : "\uf028";
                            }
                            color: (MprisState.player?.volume ?? 0) <= 0.001 ? Themes.muted : Themes.pink
                            font {
                                pixelSize: 9
                                family: "Symbols Nerd Font Mono"
                            }
                        }

                        BarText {
                            anchors.centerIn: parent
                            // current player's glyph replaces the play/pause symbol —
                            // state is hinted by ring/icon colour
                            visible: !mprisRoot.showVolume
                            symbolText: MprisState.appGlyph(MprisState.player)
                            baseColor: (MprisState.player?.isPlaying ?? false) ? Themes.pink : Themes.muted
                            color: (MprisState.player?.isPlaying ?? false) ? Themes.pink : Themes.muted
                            pointSize: 10
                            symbolSize: 10
                            paddingg: 0
                        }
                    }

                }
            }
        }
    }

    // ── popup (lives outside the mouse area, never destroyed by Loader) ──
    LazyLoader {
        loading: mprisRoot.showPopup

        PopupWindow {
            id: popup

            // anchor.window: mprisRoot.host
            // anchor.rect.x: mprisRoot.host.width / 2 - width / 2
            // anchor.rect.y: 35
            anchor.window: mprisRoot.host
            anchor.rect.x: {
                let g = mprisRoot.mapToGlobal(0, 0);
                return Math.max(4, Math.min(g.x + mprisRoot.width / 2 - width / 2,
                    mprisRoot.host.width - width - 4));
            }
            anchor.rect.y: 35
            visible: mprisRoot.showPopup
            grabFocus: true
            color: "transparent"
            implicitWidth: 280
            implicitHeight: Math.min(mprisPopupContent.implicitHeight + 16, 320)

            Rectangle {
                id: mprisPopupRect
                anchors.fill: parent
                focus: true
                radius: 10
                color: Themes.popupCardBg
                border.width: 1
                border.color: Themes.borderMuted

                Keys.onEscapePressed: mprisRoot.showPopup = false

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
        loading: mprisRoot.showArtPopup

        PopupWindow {
            id: artPopup

            anchor.window: mprisRoot.host
            anchor.rect.x: {
                let g = mprisRoot.mapToGlobal(0, 0);
                return Math.max(4, Math.min(g.x + mprisRoot.width / 2 - width / 2,
                    mprisRoot.host.width - width - 4));
            }
            anchor.rect.y: 35
            visible: mprisRoot.showArtPopup && MprisState.player !== null
            grabFocus: true
            color: "transparent"
            implicitWidth: 280
            implicitHeight: 280

            Rectangle {
                id: artPopupRect
                anchors.fill: parent
                focus: true
                radius: 12
                color: Themes.popupCardBg
                border.width: 1
                border.color: Themes.borderMuted

                Keys.onEscapePressed: mprisRoot.showArtPopup = false

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
                    color: Themes.accent
                    font {
                        pixelSize: 42
                        family: "Symbols Nerd Font Mono"
                    }
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
