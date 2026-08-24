pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.customItems
import qs.services
import qs.bar.quicksettings.nowplaying

// ═══ NOW PLAYING ═══
// self-contained media card — compact strip + expanded art view.
// Set `compactNowPlaying` from the host to switch views.
// A chevron at the bottom-right extends the card below the track
// buttons, revealing a stream list to pick the controlled player from.
ClippingRectangle {
    id: card

    required property bool compactNowPlaying

    // ── player chooser state ──
    // chevron toggles the reveal; needs a real choice to offer
    property bool chooserOpen: false

    readonly property bool chooserAvailable: MiscState.showPlayerChooser && MprisState.controlPlayers.length > 1

    onChooserAvailableChanged: {
        if (!chooserAvailable)
            chooserOpen = false;
    }

    readonly property int baseCardHeight: compactNowPlaying ? 82 : 260
                    radius: 10
                    visible: MprisState.cardPlayer !== null
                    color: {
                        if (MprisState.cardPlayer?.trackArtUrl)
                            return Qt.rgba(card.dominantColor.r, card.dominantColor.g, card.dominantColor.b, 0.12);
                        return "#21222c";
                    }
                    implicitHeight: baseCardHeight + (chooserAvailable && chooserOpen ? chooserPanel.implicitHeight : 0)
                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    // chevron that extends the card to reveal the stream list —
                    // flips over while the drawer is open
                    component ChooserChevron: TrackButton {
                        width: 20
                        height: 20
                        ghost: true
                        text: "\uf078"
                        idleColor: Qt.rgba(1, 1, 1, 0.32)
                        accentColor: Qt.rgba(1, 1, 1, 0.75)
                        rotation: card.chooserOpen ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        onClicked: card.chooserOpen = !card.chooserOpen
                    }

                    property color dominantColor: "#bd93f9"
                    border {
                        width: 1
                        color: Qt.rgba(card.dominantColor.r, card.dominantColor.g, card.dominantColor.b, 0.35)
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 300
                        }
                    }

                    property int progressTick: 0
                    property bool showVolumeBadge: false
                    // middle-click mute state · expanded controls gate
                    readonly property bool mutedNow: MprisState.isMuted(MprisState.cardPlayer)
                    property bool expControlsRevealed: false
                    // external players (no MPRIS volume, e.g. chrome) get a
                    // locally tracked percentage since pactl can't be read back
                    property real extVol: 0.5
                    readonly property bool mprisVolume: MprisState.cardPlayer?.volumeSupported ?? false
                    readonly property int currentVolume: Math.round((mprisVolume ? MprisState.cardPlayer?.volume ?? 0 : extVol) * 100)

                    // visibility-first volume tint — hotter as it gets louder;
                    // muted drops to red regardless of level
                    readonly property color volumeColor: mutedNow || currentVolume <= 0 ? "#ff5555" : currentVolume > 80 ? "#ff79c6" : currentVolume > 50 ? "#c6a0f6" : "#bd93f9"

                    Timer {
                        id: volumeBadgeTimer
                        interval: 800
                        running: false
                        repeat: false
                        onTriggered: card.showVolumeBadge = false
                    }

                    // scroll anywhere on the card (compact OR expanded) to adjust
                    // player volume — a HUD replaces the art while active;
                    // players without MPRIS volume fall back to wpctl
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: ev => {
                            const p = MprisState.cardPlayer;
                            if (!(p?.canControl))
                                return;
                            if (card.mprisVolume) {
                                MprisState.adjustVolume(p, ev.angleDelta.y > 0);
                            } else {
                                card.extVol = Math.max(0, Math.min(card.extVol + (ev.angleDelta.y > 0 ? 0.05 : -0.05), 1));
                                MprisState.adjustVolume(p, ev.angleDelta.y > 0);
                            }
                            card.showVolumeBadge = true;
                            volumeBadgeTimer.restart();
                            ev.accepted = true;
                        }
                    }

                    // ── Hidden helpers ──
                    Item {
                        visible: false
                        width: 0
                        height: 0

                        Image {
                            id: hiddenArt
                            source: MprisState.artFor(MprisState.cardPlayer)
                            asynchronous: true
                            onStatusChanged: {
                                if (status === Image.Ready)
                                    colorSampler.requestPaint();
                                else if (status === Image.Null || status === Image.Error)
                                    card.dominantColor = "#bd93f9";
                            }
                        }

                        Canvas {
                            id: colorSampler
                            width: 3
                            height: 3
                            onPaint: {
                                var ctx = getContext("2d");
                                if (hiddenArt.status !== Image.Ready)
                                    return;
                                try {
                                    var n = 3;
                                    ctx.clearRect(0, 0, n, n);
                                    ctx.drawImage(hiddenArt, 0, 0, n, n);
                                    var d = ctx.getImageData(0, 0, n, n).data;
                                    var r = 0, g = 0, b = 0, cnt = 0;
                                    for (var i = 0; i < d.length; i += 4) {
                                        if (d[i + 3] < 200)
                                            continue;
                                        r += d[i];
                                        g += d[i + 1];
                                        b += d[i + 2];
                                        cnt++;
                                    }
                                    if (cnt === 0)
                                        return;
                                    r = r / (cnt * 255);
                                    g = g / (cnt * 255);
                                    b = b / (cnt * 255);
                                    var lum = 0.299 * r + 0.587 * g + 0.114 * b;
                                    if (lum < 0.15) {
                                        r = Math.min(1, r + 0.15);
                                        g = Math.min(1, g + 0.15);
                                        b = Math.min(1, b + 0.15);
                                    }
                                    card.dominantColor = Qt.rgba(r, g, b, 1.0);
                                } catch (e) {}
                            }
                        }

                        Timer {
                            interval: 1000
                            running: MprisState.cardPlayer?.isPlaying ?? false
                            repeat: true
                            onTriggered: card.progressTick++
                        }
                    }

                    // ── COMPACT VIEW ──
                    // pinned to the card top with its base height so the
                    // chooser drawer can claim the space below it
                    Item {
                        id: compactView
                        visible: card.compactNowPlaying
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                        }
                        height: baseCardHeight

                        // TODO: have trackbutton here
                        TrackButton {
                            text: "+"
                            ghost: true
                            // accentColor: "#6272a4"
                            accentColor: card.color
                            onClicked: card.compactNowPlaying = false
                            // Layout.rightMargin: 4
                            anchors {
                                right: parent.right
                                top: parent.top
                                rightMargin: 2
                                topMargin: 2
                            }
                        }

                        // (chooser chevron lives in the controls row below,
                        // bottom-right on the same line as the track buttons)
                        RowLayout {
                            anchors.fill: parent
                            // spacing: 10

                            ClippingRectangle {
                                id: compactArt

                                contentUnderBorder: true

                                Layout.fillHeight: true
                                Layout.minimumWidth: height
                                // radius: 2
                                color: compactArtImage.status === Image.Ready ? Qt.rgba(card.dominantColor.r, card.dominantColor.g, card.dominantColor.b, 0.15) : "#343746"

                                border {
                                    width: compactArtImage.status === Image.Ready ? 1 : 0
                                    color: Qt.rgba(card.dominantColor.r, card.dominantColor.g, card.dominantColor.b, 0.2)
                                }

                                Image {
                                    id: compactArtImage
                                    anchors.fill: parent
                                    source: MprisState.artFor(MprisState.cardPlayer)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    mipmap: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    // browser glyph for browsers, music note for anyone else without art
                                    text: !MprisState.cardPlayer ? "" : MprisState.isBrowserPlayer(MprisState.cardPlayer) ? MprisState.browserGlyph(MprisState.cardPlayer) : "\uf001"
                                    color: "#6272a4"
                                    font {
                                        pixelSize: 24
                                        family: "Symbols Nerd Font Mono"
                                    }
                                    visible: compactArtImage.status !== Image.Ready
                                }

                                // ── volume HUD — scrimmed over the art ──
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Qt.rgba(0, 0, 0, 0.6)
                                    visible: card.showVolumeBadge
                                    opacity: visible ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 140
                                            easing.type: Easing.OutQuad
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: card.mutedNow ? "\uf026" : `${card.currentVolume}%`
                                        color: card.mutedNow ? "#ff5555" : "#f8f8f2"
                                        font {
                                            pixelSize: 19
                                            bold: true
                                            family: "ZedMono Nerd Font"
                                        }
                                    }
                                }
                            }

                            // ── Info panel ──
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 2

                                // ── Title + row ──
                                // right margin keeps the marquee clear of the
                                // + / player-switch buttons in the top-right
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.rightMargin: 34
                                    spacing: 4

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        MarqueeText {
                                            Layout.fillWidth: true
                                            scrolling: MprisState.marqueeEnabled
                                            text: MprisState.cardPlayer?.trackTitle || "No track"
                                            textColor: "#f8f8f2"
                                            fontFamily: "Quicksand"
                                            fontBold: true
                                            pixelSize: 11
                                            maxWidth: 4096
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: MprisState.cardPlayer?.trackArtist || ""
                                            color: "#b8bfcb"
                                            font {
                                                pixelSize: 9
                                                // family: "ZedMono Nerd Font"
                                                family: "nunito"
                                            }
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            visible: text.length > 0
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                // ── Progress bar ──
                                Item {
                                    id: seekBar

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 10
                                    Layout.rightMargin: 6

                                    readonly property real ratio: {
                                        card.progressTick;
                                        var p = MprisState.cardPlayer;
                                        if (!p)
                                            return 0;
                                        var pos = p.position;
                                        var len = p.length;
                                        if (pos == null || len == null || len <= 0 || isNaN(pos) || isNaN(len))
                                            return 0;
                                        return Math.min(pos / len, 1);
                                    }

                                    HoverHandler {
                                        id: seekHover
                                    }

                                    // track — thickens slightly under the cursor
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: seekHover.hovered ? 5 : 3
                                        radius: height / 2
                                        color: Qt.rgba(1, 1, 1, 0.09)

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }
                                        }

                                        // fill with a soft sheen toward the playhead
                                        Rectangle {
                                            width: parent.width * seekBar.ratio
                                            height: parent.height
                                            radius: height / 2
                                            color: card.dominantColor

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 200
                                                    easing.type: Easing.Linear
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                visible: seekHover.hovered
                                                gradient: Gradient {
                                                    orientation: Gradient.Horizontal
                                                    GradientStop {
                                                        position: 0
                                                        color: Qt.rgba(1, 1, 1, 0)
                                                    }
                                                    GradientStop {
                                                        position: 1
                                                        color: Qt.rgba(1, 1, 1, 0.25)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // playhead knob — appears on hover
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: (parent.width - width) * seekBar.ratio
                                        width: seekHover.hovered ? 9 : 0
                                        height: width
                                        radius: width / 2
                                        color: "#f8f8f2"
                                        border.width: 2
                                        border.color: card.dominantColor

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 120
                                                easing.type: Easing.OutQuad
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            var p = MprisState.cardPlayer;
                                            if (p && p.length > 0)
                                                p.position = (mouse.x / width) * p.length;
                                        }
                                    }
                                }

                                // ── Controls ──
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    TrackButton {
                                        text: "\uf048"
                                        flat: true
                                        accentColor: "#8be9fd"
                                        onClicked: MprisState.cardPlayer?.previous()
                                    }
                                    TrackButton {
                                        id: compactPlay

                                        text: MprisState.cardPlayer?.isPlaying ? "\uf04c" : "\uf04b"
                                        flat: true
                                        accentColor: "#bd93f9"
                                        onClicked: MprisState.cardPlayer?.togglePlaying()
                                    }
                                    TrackButton {
                                        text: "\uf050"
                                        flat: true
                                        accentColor: "#ff79c6"
                                        onClicked: MprisState.cardPlayer?.next()
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    // player chooser — bottom-right, same row
                                    // as the transport; only with >1 player
                                    ChooserChevron {
                                        visible: card.chooserAvailable
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                            }
                        }
                    }

                        // ── EXPANDED VIEW ──
                        Item {
                            visible: !card.compactNowPlaying
                            // art fills the card edge-to-edge — no gap
                            // between the border container and the image;
                            // base height keeps the chooser drawer below it
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                            }
                            height: baseCardHeight

                        // controls always start tucked away
                        onVisibleChanged: {
                            if (visible)
                                card.expControlsRevealed = false;
                        }
                        // implicitHeight: 100
                        // implicitWidth: 100

                        // ── Album art background ──
                        ClippingRectangle {
                            anchors.fill: parent
                            radius: 8
                            color: {
                                if (MprisState.artFor(MprisState.cardPlayer).length > 0)
                                    return Qt.rgba(card.dominantColor.r, card.dominantColor.g, card.dominantColor.b, 0.12);
                                return "#21222c";
                            }

                            Image {
                                id: expandedArtImage
                                anchors.fill: parent
                                source: MprisState.artFor(MprisState.cardPlayer)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                // browser glyph for browsers, music note for anyone else without art
                                text: !MprisState.cardPlayer ? "" : MprisState.isBrowserPlayer(MprisState.cardPlayer) ? MprisState.browserGlyph(MprisState.cardPlayer) : "\uf001"
                                color: "#6272a4"
                                font {
                                    pixelSize: 56
                                    family: "Symbols Nerd Font Mono"
                                }
                                visible: expandedArtImage.status !== Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, 0.5)
                            }
                        }

                        // ── Controls overlay ──
                        Item {
                            anchors.fill: parent

                            // ── seek bar + transport — slide up above
                            // the track text once revealed ──
                            ColumnLayout {
                                id: expRevealCol

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: expInfoCol.top
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.bottomMargin: 8
                                spacing: 6

                                enabled: card.expControlsRevealed
                                opacity: card.expControlsRevealed ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                transform: Translate {
                                    y: card.expControlsRevealed ? 0 : 14

                                    Behavior on y {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                // ── Progress bar ──
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 16

                                    readonly property real ratio: {
                                        card.progressTick;
                                        var p = MprisState.cardPlayer;
                                        if (!p)
                                            return 0;
                                        var pos = p.position;
                                        var len = p.length;
                                        if (pos == null || len == null || len <= 0 || isNaN(pos) || isNaN(len))
                                            return 0;
                                        return Math.min(pos / len, 1);
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 4
                                        radius: 2
                                        color: Qt.rgba(1, 1, 1, 0.12)

                                        Rectangle {
                                            width: parent.width * parent.parent.ratio
                                            height: parent.height
                                            radius: 2
                                            color: card.dominantColor

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 200
                                                    easing.type: Easing.Linear
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            var p = MprisState.cardPlayer;
                                            if (p && p.length > 0)
                                                p.position = (mouse.x / width) * p.length;
                                        }
                                    }
                                }

                                // ── Playback controls ──
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    spacing: 8

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    TrackButton {
                                        text: "\uf074"
                                        visible: MiscState.showShuffle
                                        active: MprisState.cardPlayer?.shuffle ?? false
                                        accentColor: MprisState.cardPlayer?.shuffle ? "#ff79c6" : Qt.rgba(1, 1, 1, 0.45)
                                        onClicked: {
                                            var p = MprisState.cardPlayer;
                                            if (p?.canControl && p?.shuffleSupported)
                                                p.shuffle = !p.shuffle;
                                        }
                                    }
                                    TrackButton {
                                        text: "\uf049"
                                        accentColor: "#8be9fd"
                                        onClicked: MprisState.cardPlayer?.previous()
                                    }
                                    TrackButton {
                                        text: MprisState.cardPlayer?.isPlaying ? "\uf04c" : "\uf04b"
                                        accentColor: "#bd93f9"
                                        onClicked: MprisState.cardPlayer?.togglePlaying()
                                    }
                                    TrackButton {
                                        text: "\uf050"
                                        accentColor: "#ff79c6"
                                        onClicked: MprisState.cardPlayer?.next()
                                    }
                                    TrackButton {
                                        text: "\uf079"
                                        visible: MiscState.showLoop
                                        active: MprisState.cardPlayer?.loopState !== MprisLoopState.None
                                        accentColor: MprisState.cardPlayer?.loopState === MprisLoopState.Track ? "#50fa7b" : MprisState.cardPlayer?.loopState === MprisLoopState.Playlist ? "#bd93f9" : Qt.rgba(1, 1, 1, 0.45)
                                        onClicked: {
                                            var p = MprisState.cardPlayer;
                                            if (!p?.canControl || !p?.loopSupported)
                                                return;
                                            var ls = p.loopState;
                                            if (ls === MprisLoopState.None)
                                                p.loopState = MprisLoopState.Track;
                                            else if (ls === MprisLoopState.Track)
                                                p.loopState = MprisLoopState.Playlist;
                                            else
                                                p.loopState = MprisLoopState.None;
                                        }
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            // ── track text — bottom left · clicking it
                            // raises / hides the seek bar + transport.
                            // right-anchored so long titles stay inside
                            // the card and marquee-scroll ──
                                ColumnLayout {
                                    id: expInfoCol

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    // snug to the image edge — thin margins only
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 34
                                    anchors.bottomMargin: 6
                                    spacing: 1

                                MarqueeText {
                                    Layout.fillWidth: true
                                    text: MprisState.cardPlayer?.trackTitle || "No track"
                                    textColor: "#ffffff"
                                    // fontFamily: "FantasqueSansM Nerd Font"
                                    fontFamily: "nunito"
                                    fontBold: true
                                    pixelSize: 18
                                    maxWidth: 420
                                }

                                MarqueeText {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: MprisState.cardPlayer?.trackArtist || ""
                                    textColor: Qt.rgba(1, 1, 1, 0.7)
                                    fontFamily: "ZedMono Nerd Font"
                                    fontBold: false
                                    pixelSize: 12
                                    maxWidth: 420
                                }

                                HoverHandler {
                                    id: expInfoHover
                                }

                                // tap anywhere on the track text to raise/hide
                                // the seek bar + transport (handler, not a layout
                                // child — keeps the column geometry untouched)
                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    cursorShape: Qt.PointingHandCursor
                                    onTapped: card.expControlsRevealed = !card.expControlsRevealed
                                }
                            }
                        }

                        TrackButton {
                            text: "−"
                            ghost: true
                            accentColor: Qt.rgba(1, 1, 1, 0.6)
                            onClicked: card.compactNowPlaying = true
                            anchors {
                                right: parent.right
                                top: parent.top
                                rightMargin: 2
                                topMargin: 2
                            }
                        }

                        // player chooser toggle — bottom-right chevron,
                        // lifted to the track-text level
                        ChooserChevron {
                            visible: card.chooserAvailable
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                rightMargin: 6
                                bottomMargin: 6
                            }
                        }

                        // ── volume HUD — large clean scrim flash;
                        // red speaker-x while muted ──
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.62)
                            visible: card.showVolumeBadge
                            opacity: visible ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutQuad
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: card.mutedNow ? "\uf026" : `${card.currentVolume}%`
                                    color: card.mutedNow ? "#ff5555" : "#f8f8f2"
                                    font {
                                        pixelSize: 64
                                        bold: true
                                        family: "ZedMono Nerd Font"
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: card.mutedNow ? "MUTED" : "VOLUME"
                                    color: card.mutedNow ? Qt.rgba(1, 0.33, 0.33, 0.8) : Qt.rgba(1, 1, 1, 0.45)
                                    font {
                                        pixelSize: 9
                                        bold: true
                                        letterSpacing: 6
                                        family: "Quicksand"
                                    }
                                }
                            }
                        }
                    }

                    // ── PLAYER CHOOSER DRAWER ──
                    // revealed below the track buttons by the bottom-right
                    // chevron; lists every MPRIS stream — click to hand the
                    // card over, right-click to mute that stream, wheel to
                    // step through them
                    Rectangle {
                        id: chooserPanel

                        visible: card.chooserAvailable && opacity > 0
                        opacity: card.chooserOpen ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                        }

                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        implicitHeight: chooserCol.implicitHeight + 14
                        // slightly darker floor so the drawer reads as its own zone
                        color: Qt.rgba(0, 0, 0, 0.25)

                        // hairline divider in the dominant color ties it to the art
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(card.dominantColor.r, card.dominantColor.g, card.dominantColor.b, 0.4)
                        }

                        // wheel anywhere on the drawer steps through players
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: ev => {
                                MprisState.moveCardPin(ev.angleDelta.y > 0 ? -1 : 1);
                                ev.accepted = true;
                            }
                        }

                        ColumnLayout {
                            id: chooserCol

                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 7
                                topMargin: 8
                            }
                            spacing: 2

                            Repeater {
                                model: MprisState.controlPlayers

                                delegate: Rectangle {
                                    id: streamRow

                                    required property var modelData

                                    readonly property bool isCurrent: modelData.identity === (MprisState.cardPlayer?.identity ?? "")
                                    readonly property bool isPinned: MprisState.pinIdentity === modelData.identity
                                    readonly property bool isPlaying: {
                                        try {
                                            return modelData.playbackState === MprisPlaybackState.Playing;
                                        } catch (e) {
                                            return false;
                                        }
                                    }
                                    readonly property bool isMuted: MprisState.isMuted(modelData)

                                    Layout.fillWidth: true
                                    implicitHeight: 24
                                    radius: 6
                                    color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08)
                                        : isCurrent ? Qt.rgba(1, 1, 1, 0.05)
                                        : "transparent"

                                    Behavior on color {
                                        ColorAnimation { duration: 110 }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Text {
                                            text: MprisState.appGlyph(streamRow.modelData)
                                            color: streamRow.isCurrent ? card.dominantColor : "#6272a4"
                                            font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: streamRow.modelData?.identity ?? ""
                                            elide: Text.ElideRight
                                            color: streamRow.isCurrent ? "#f8f8f2" : "#b8bfcb"
                                            font {
                                                pixelSize: 10
                                                bold: streamRow.isCurrent
                                                family: "Quicksand"
                                            }
                                        }

                                        // muted marker
                                        Text {
                                            visible: streamRow.isMuted
                                            text: "\uf026"
                                            color: "#ff5555"
                                            font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
                                        }

                                        // playing marker
                                        Text {
                                            visible: streamRow.isPlaying
                                            text: "\uf04b"
                                            color: "#50fa7b"
                                            font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                                        }

                                        // pin marker — this player drives the card
                                        Text {
                                            visible: streamRow.isPinned
                                            text: "\uf08d"
                                            color: "#f1fa8c"
                                            font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                                        }
                                    }

                                    MouseArea {
                                        id: rowMa

                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                if (streamRow.modelData?.canControl)
                                                    MprisState.toggleMute(streamRow.modelData);
                                                return;
                                            }
                                            // clicking the shown player releases an explicit pin
                                            MprisState.pinIdentity = streamRow.isCurrent && MprisState.pinIdentity.length > 0
                                                ? "" : streamRow.modelData.identity;
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "click switches · right-click mutes · scroll steps"
                                color: "#6272a4"
                                font {
                                    pixelSize: 8
                                    family: "Quicksand"
                                    letterSpacing: 0.5
                                }
                            }
                        }
                    }

                // middle- OR right-click anywhere on the card mutes /
                // unmutes the player in control — the volume
                // HUD flashes the state as feedback
                TapHandler {
                    acceptedButtons: Qt.MiddleButton | Qt.RightButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        const p = MprisState.cardPlayer;
                        if (!(p?.canControl))
                            return;
                        MprisState.toggleMute(p);
                        card.showVolumeBadge = true;
                        volumeBadgeTimer.restart();
                    }
                }
}
