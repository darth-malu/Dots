pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.customItems
import qs.services
import qs.bar.quicksettings.nowplaying
import qs.themes

// ═══ NOW PLAYING ═══
// self-contained media card — compact strip + expanded art view.
// Set `compactNowPlaying` from the host to switch views.
// A cog at the bottom-right extends the card below the track
// buttons, revealing a stream list to pick the controlled player from.
ClippingRectangle {
    id: card

    required property bool compactNowPlaying

    // ── player chooser state ──
    // cog toggles the reveal; needs a real choice to offer
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
        return Themes.cardBg;
    }
    implicitHeight: baseCardHeight + (chooserAvailable && chooserOpen ? chooserPanel.implicitHeight : 0)

    // combined control — one button for both card duties, styled to
    // match the audio volume card's management cog: left-click runs the
    // caller's primary action (expand/collapse the art view), right-click
    // opens the player chooser; lights up while the chooser drawer is open
    component ChooserCog: Rectangle {
        id: cog

        signal clicked
        signal openChooser()

        implicitWidth: 18
        implicitHeight: 18
        radius: 5
        color: cogMouse.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.18) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            anchors.centerIn: parent
            text: "\uf067"
            color: card.chooserOpen || cogMouse.containsMouse ? Themes.accent : Themes.muted
            font {
                pixelSize: 10
                family: "Symbols Nerd Font Mono"
            }

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        MouseArea {
            id: cogMouse

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    cog.openChooser();
                else
                    cog.clicked();
            }
        }
    }

    property color dominantColor: Themes.accent
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
    property bool expControlsRevealed: false
    // external players (no MPRIS volume, e.g. chrome): resolve the real per-app
    // pipewire stream node so scroll volume edits the actual settings (same
    // logic as the audio > applications list) instead of a local guess
    readonly property bool mprisVolume: MprisState.cardPlayer?.volumeSupported ?? false
    readonly property var extNode: {
        const p = MprisState.cardPlayer;
        if (!p || p.volumeSupported)
            return null;
        return PipewireState.appStreamForPlayer(p);
    }
    readonly property bool mutedNow: mprisVolume
        ? MprisState.isMuted(MprisState.cardPlayer)
        : extNode ? (extNode.audio?.muted ?? false) : false
    // external players without a resolvable stream fall back to a locally
    // tracked percentage (only used when node lookup yields nothing)
    property real extVol: 0.5
    readonly property int currentVolume: Math.round((mprisVolume
        ? (MprisState.cardPlayer?.volume ?? 0)
        : extNode ? (extNode.audio?.volume ?? 0) : extVol) * 100)

    // visibility-first volume tint — hotter as it gets louder;
    // muted drops to red regardless of level
    readonly property color volumeColor: mutedNow || currentVolume <= 0 ? "#ff5555" : currentVolume > 80 ? Themes.pink : currentVolume > 50 ? Themes.mauve : Themes.accent

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
                // spotify etc. adjust natively via MPRIS
                MprisState.adjustVolume(p, ev.angleDelta.y > 0);
            } else if (card.extNode) {
                // chrome: same logic as the audio > applications slider — edit
                // the real per-app pipewire stream volume directly
                const step = ev.angleDelta.y > 0 ? 0.05 : -0.05;
                const base = card.extNode.audio?.volume ?? 0;
                card.extNode.audio.volume = Math.max(0, Math.min(base + step, 1));
            } else {
                // no resolvable stream — local fallback + wpctl nudge
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
                    card.dominantColor = Themes.accent;
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
    Item {
        id: compactView
        visible: card.compactNowPlaying
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: baseCardHeight

        RowLayout {
            anchors.fill: parent

            ClippingRectangle {
                id: compactArt

                contentUnderBorder: true

                Layout.fillHeight: true
                Layout.minimumWidth: height
                color: compactArtImage.status === Image.Ready ? Qt.rgba(card.dominantColor.r, card.dominantColor.g, card.dominantColor.b, 0.15) : Themes.separator

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
                    text: !MprisState.cardPlayer ? "" : MprisState.isBrowserPlayer(MprisState.cardPlayer) ? MprisState.browserGlyph(MprisState.cardPlayer) : "\uf001"
                    color: Themes.muted
                    font {
                        pixelSize: 24
                        family: "Symbols Nerd Font Mono"
                    }
                    visible: compactArtImage.status !== Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Qt.rgba(0, 0, 0, 0.6)
                    visible: card.showVolumeBadge
                    opacity: visible ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: card.mutedNow ? "\uf026" : `${card.currentVolume}%`
                        color: card.mutedNow ? "#ff5555" : Themes.fg
                        font {
                            pixelSize: 19
                            bold: true
                            family: "ZedMono Nerd Font"
                        }
                    }
                }
            }

            // ── Right panel — title, progress, controls ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 4
                Layout.leftMargin: 4
                Layout.rightMargin: 30
                spacing: 2

                MarqueeText {
                    Layout.fillWidth: true
                    scrolling: MprisState.marqueeEnabled
                    text: MprisState.cardPlayer?.trackTitle || "No track"
                    textColor: Themes.fg
                    fontFamily: "Quicksand"
                    fontBold: true
                    pixelSize: 11
                    maxWidth: 4096
                }

                Text {
                    Layout.fillWidth: true
                    text: MprisState.cardPlayer?.trackArtist || ""
                    color: Themes.dim
                    font {
                        pixelSize: 10
                        family: "Quicksand"
                        bold: true
                    }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }

                // progress bar
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10

                    readonly property real ratio: {
                        card.progressTick;
                        var p = MprisState.cardPlayer;
                        if (!p) return 0;
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
                        height: 3
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.09)

                        Rectangle {
                            width: parent.width * parent.parent.ratio
                            height: parent.height
                            radius: height / 2
                            color: card.dominantColor

                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.Linear }
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

                // transport controls — centered below progress bar
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 4

                    Item { Layout.fillWidth: true }
                    TrackButton {
                        text: "\uf048"
                        flat: true
                        accentColor: Themes.accent2
                        onClicked: MprisState.cardPlayer?.previous()
                    }
                    TrackButton {
                        text: MprisState.cardPlayer?.isPlaying ? "\uf04c" : "\uf04b"
                        flat: true
                        accentColor: Themes.accent
                        onClicked: MprisState.cardPlayer?.togglePlaying()
                    }
                    TrackButton {
                        text: "\uf050"
                        flat: true
                        accentColor: Themes.pink
                        onClicked: MprisState.cardPlayer?.next()
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        ChooserCog {
            // left = expand to the art view, right = player chooser
            onClicked: card.compactNowPlaying = false
            onOpenChooser: card.chooserOpen = !card.chooserOpen
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: 4
                topMargin: 4
            }
        }
    }

    // ── EXPANDED VIEW ──
    Item {
        id: expandedView

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
                return Themes.cardBg;
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
                color: Themes.muted
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

            // ── title + controls — anchored to bottom, revealing pushes title up ──
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 12
                anchors.bottomMargin: 8
                spacing: 6

                // ── seek bar + transport ──
                ColumnLayout {
                    id: expRevealCol

                    Layout.fillWidth: true
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
                            accentColor: MprisState.cardPlayer?.shuffle ? Themes.pink : Qt.rgba(1, 1, 1, 0.45)
                            onClicked: {
                                var p = MprisState.cardPlayer;
                                if (p?.canControl && p?.shuffleSupported)
                                    p.shuffle = !p.shuffle;
                            }
                        }
                        TrackButton {
                            text: "\uf049"
                            accentColor: Themes.accent2
                            onClicked: MprisState.cardPlayer?.previous()
                        }
                        TrackButton {
                            text: MprisState.cardPlayer?.isPlaying ? "\uf04c" : "\uf04b"
                            accentColor: Themes.accent
                            onClicked: MprisState.cardPlayer?.togglePlaying()
                        }
                        TrackButton {
                            text: "\uf050"
                            accentColor: Themes.pink
                            onClicked: MprisState.cardPlayer?.next()
                        }
                        TrackButton {
                            text: "\uf079"
                            visible: MiscState.showLoop
                            active: MprisState.cardPlayer?.loopState !== MprisLoopState.None
                            accentColor: MprisState.cardPlayer?.loopState === MprisLoopState.Track ? "#50fa7b" : MprisState.cardPlayer?.loopState === MprisLoopState.Playlist ? Themes.accent : Qt.rgba(1, 1, 1, 0.45)
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

                // ── track text — bottom ──
                ColumnLayout {
                    id: expInfoCol

                    Layout.fillWidth: true
                    Layout.rightMargin: 22
                    spacing: 1

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        cursorShape: Qt.PointingHandCursor
                        onTapped: card.expControlsRevealed = !card.expControlsRevealed
                    }

                    MarqueeText {
                        Layout.fillWidth: true
                        text: MprisState.cardPlayer?.trackTitle || "No track"
                        textColor: "#ffffff"
                        fontFamily: "quicksand"
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
                }
            }
        }

        ChooserCog {
            // left = collapse back to compact, right = player chooser
            onClicked: card.compactNowPlaying = true
            onOpenChooser: card.chooserOpen = !card.chooserOpen
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: 2
                topMargin: 2
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
                    color: card.mutedNow ? "#ff5555" : Themes.fg
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
    // revealed by right-clicking the card's cog; lists every MPRIS
    // stream — click to hand the card over, right-click to mute that
    // stream, wheel to step through them
    Rectangle {
        id: chooserPanel

        visible: card.chooserAvailable && card.chooserOpen

        // pinned below the base view so the card clip wipes it into view
        anchors {
            left: parent.left
            right: parent.right
            top: card.compactNowPlaying ? compactView.bottom : expandedView.bottom
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
                    readonly property bool isPinned: MprisState.pinPlayerName === modelData.dbusName
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
                    color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : isCurrent ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: MprisState.appGlyph(streamRow.modelData)
                            color: streamRow.isCurrent ? card.dominantColor : Themes.muted
                            font {
                                pixelSize: 11
                                family: "Symbols Nerd Font Mono"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: streamRow.modelData?.identity ?? ""
                            elide: Text.ElideRight
                            color: streamRow.isCurrent ? Themes.fg : Themes.dim
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
                            font {
                                pixelSize: 9
                                family: "Symbols Nerd Font Mono"
                            }
                        }

                        // playing marker
                        Text {
                            visible: streamRow.isPlaying
                            text: "\uf04b"
                            color: "#50fa7b"
                            font {
                                pixelSize: 8
                                family: "Symbols Nerd Font Mono"
                            }
                        }

                        // pin marker — this player drives the card
                        Text {
                            visible: streamRow.isPinned
                            text: "\uf08d"
                            color: "#f1fa8c"
                            font {
                                pixelSize: 8
                                family: "Symbols Nerd Font Mono"
                            }
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
                            MprisState.pinPlayerName = streamRow.isCurrent && MprisState.pinPlayerName.length > 0 ? "" : streamRow.modelData.dbusName;
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "click switches · right-click mutes · scroll steps"
                color: Themes.muted
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


