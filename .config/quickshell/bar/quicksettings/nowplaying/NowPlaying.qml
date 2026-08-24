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
ClippingRectangle {
    id: card

    required property bool compactNowPlaying

    component PlayerStrip: Item {
        id: strip

        implicitWidth: 20
        implicitHeight: 20

        readonly property bool multi: MprisState.controlPlayers.length > 1
        readonly property color accent: MprisState.pinIdentity.length > 0 ? "#f1fa8c" : Qt.rgba(1, 1, 1, 0.65)

        // generous invisible hover zone around the bottom-left corner
        MouseArea {
            id: zoneMa
            anchors.fill: parent
            anchors.margins: -26
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        // launcher button — only fades in while the region is hovered
        Rectangle {
            id: launchBtn

            anchors.centerIn: parent
            width: 20
            height: 20
            radius: height / 2
            visible: strip.multi && !strip.open
            opacity: zoneMa.containsMouse || launchMa.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 130 }
            }

            color: launchMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            border.color: strip.accent

            Text {
                anchors.centerIn: parent
                text: "\uf142" // kebab / list glyph
                color: "#f8f8f2"
                font {
                    pixelSize: 9
                    family: "Symbols Nerd Font Mono"
                }
            }

            MouseArea {
                id: launchMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        MprisState.jumpToPlaying();
                    else
                        strip.open = !strip.open;
                }
            }
        }

        // expanded chip row
        Row {
            id: chipRow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            opacity: strip.open ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            Repeater {
                model: MprisState.controlPlayers

                delegate: Item {
                    id: chip

                    required property var modelData

                    readonly property bool isCurrent: modelData.identity === (MprisState.cardPlayer?.identity ?? "")
                    readonly property bool hovered: chipMa.containsMouse

                    width: 20
                    height: 20

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: chip.isCurrent ? Qt.rgba(1, 1, 1, 0.14)
                            : chip.hovered ? Qt.rgba(1, 1, 1, 0.08)
                            : Qt.rgba(0, 0, 0, 0.4)
                        border.width: chip.isCurrent ? 1 : 0
                        border.color: strip.accent
                    }

                    Text {
                        anchors.centerIn: parent
                        text: MprisState.appGlyph(chip.modelData)
                        color: "#f8f8f2"
                        opacity: chip.isCurrent ? 1 : 0.6
                        font {
                            pixelSize: 11
                            family: "Symbols Nerd Font Mono"
                        }
                    }

                    MouseArea {
                        id: chipMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                // right-click a player chip → mute/unmute it
                                if (chip.modelData?.canControl)
                                    MprisState.toggleMute(chip.modelData);
                                return;
                            }
                            // clicking the shown player releases an explicit pin
                            MprisState.pinIdentity = chip.isCurrent && MprisState.pinIdentity.length > 0
                                ? "" : chip.modelData.identity;
                            strip.open = false;
                        }
                    }
                }
            }
        }

        // wheel over the open strip steps through players too
        WheelHandler {
            enabled: strip.open
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => {
                MprisState.moveCardPin(ev.angleDelta.y > 0 ? -1 : 1);
                ev.accepted = true;
            }
        }

        // close when the pointer leaves the whole area
        property bool open: false
        onOpenChanged: {
            if (!zoneMa.containsMouse && !chipHover.hovered)
                closeTimer.restart();
        }

        HoverHandler {
            id: chipHover
        }

        Timer {
            id: closeTimer

            interval: 900
            onTriggered: {
                if (!zoneMa.containsMouse && !chipHover.hovered && !launchMa.containsMouse)
                    strip.open = false;
            }
        }
    }

                    radius: 10
                    visible: MprisState.cardPlayer !== null
                    color: {
                        if (MprisState.cardPlayer?.trackArtUrl)
                            return Qt.rgba(card.dominantColor.r, card.dominantColor.g, card.dominantColor.b, 0.12);
                        return "#21222c";
                    }
                    implicitHeight: card.compactNowPlaying ? 82 : 260
                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
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
                    Item {
                        id: compactView
                        visible: card.compactNowPlaying
                        anchors.fill: parent

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

                        // player chooser strip — appears only when more
                        // than one player exists; hover reveals, wheel picks
                        PlayerStrip {
                            id: compactSwitcher

                            visible: MprisState.controlPlayers.length > 1
                            z: 10
                            anchors {
left: parent.left
                                bottom: parent.bottom
leftMargin: 6
                                bottomMargin: 6
                            }
                        }

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
                                        accentColor: card.dominantColor
                                        onClicked: MprisState.cardPlayer?.previous()
                                    }
                                    TrackButton {
                                        text: MprisState.cardPlayer?.isPlaying ? "\uf04c" : "\uf04b"
                                        flat: true
                                        accentColor: card.dominantColor
                                        onClicked: MprisState.cardPlayer?.togglePlaying()
                                    }
                                    TrackButton {
                                        text: "\uf050"
                                        flat: true
                                        accentColor: card.dominantColor
                                        onClicked: MprisState.cardPlayer?.next()
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }

                        // ── EXPANDED VIEW ──
                        Item {
                            visible: !card.compactNowPlaying
                            // art fills the card edge-to-edge — no gap
                            // between the border container and the image
                            anchors.fill: parent

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
                                        accentColor: MprisState.cardPlayer?.shuffle ? "#f1fa8c" : Qt.rgba(1, 1, 1, 0.6)
                                        onClicked: {
                                            var p = MprisState.cardPlayer;
                                            if (p?.canControl && p?.shuffleSupported)
                                                p.shuffle = !p.shuffle;
                                        }
                                    }
                                    TrackButton {
                                        text: "\uf049"
                                        accentColor: Qt.rgba(1, 1, 1, 0.8)
                                        onClicked: MprisState.cardPlayer?.previous()
                                    }
                                    TrackButton {
                                        text: MprisState.cardPlayer?.isPlaying ? "\uf04c" : "\uf04b"
                                        accentColor: "#ffffff"
                                        onClicked: MprisState.cardPlayer?.togglePlaying()
                                    }
                                    TrackButton {
                                        text: "\uf050"
                                        accentColor: Qt.rgba(1, 1, 1, 0.8)
                                        onClicked: MprisState.cardPlayer?.next()
                                    }
                                    TrackButton {
                                        text: "\uf079"
                                        visible: MiscState.showLoop
                                        active: MprisState.cardPlayer?.loopState !== MprisLoopState.None
                                        accentColor: MprisState.cardPlayer?.loopState === MprisLoopState.Track ? "#f1fa8c" : MprisState.cardPlayer?.loopState === MprisLoopState.Playlist ? "#bd93f9" : Qt.rgba(1, 1, 1, 0.6)
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

                        // player chooser strip — hover reveals, wheel picks
                        PlayerStrip {
                            id: expandedSwitcher

                            visible: MprisState.controlPlayers.length > 1
                            z: 10
                            anchors {
left: parent.left
                                bottom: parent.bottom
leftMargin: 6
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

                // middle-click anywhere on the card mutes /
                // unmutes the player in control — the volume
                // HUD flashes the state as feedback
                TapHandler {
                    acceptedButtons: Qt.MiddleButton
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
