import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets

import qs.customItems
import qs.bar.quicksettings
import qs.bar.quicksettings.nowplaying
import qs.bar.quicksettings.power
import qs.services

BarBlock {
    id: root

    required property var host

    property string hostName: QuickState.hostName

    property bool playerListOpen: false
    property bool showQsPopup: false
    property bool showPowerPopup: false
    // 0 = hidden, 1 = reboot presets, 2 = shutdown presets
    property int timerPicker: 0
    property bool compactNowPlaying: true
    property bool shuffleOn: false
    property bool loopOn: false

    // true while every NAS share (Hyogo/Mutsu/Yuri) is mounted
    property bool nasAllMounted: true

    Process {
        id: nasMountCheck
        command: ["sh", "-c", "for m in Hyogo Mutsu Yuri; do systemctl is-active 'media-'$m'.mount' 2>/dev/null; done"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0 && data.trim() !== "active")
                    root.nasAllMounted = false;
            }
        }
    }

    Timer {
        id: nasRecheck
        // TODO: make this a cached/efficient process

        // fast re-poll after a remount click so the button color recovers quickly
        interval: 4000
        running: false
        repeat: true
        onTriggered: {
            if (root.nasAllMounted)
                stop();
            else
                nasMountCheck.running = true;
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.nasAllMounted = true;
            nasMountCheck.running = true;
        }
    }

    // ── volume OSD ──
    property bool osdShown: false
    property bool osdInCard: false
    property string osdGlyph: "\uf028"
    property int osdValue: 0

    function showOsd(glyph, value, inCard = false) {
        root.osdGlyph = glyph;
        root.osdValue = value;
        root.osdInCard = inCard;
        root.osdShown = true;
        osdTimer.restart();
    }

    Timer {
        id: osdTimer
        interval: 900
        running: false
        onTriggered: root.osdShown = false
    }

    onLeftClicked: {
        root.showQsPopup = !root.showQsPopup;
    }

    onShowQsPopupChanged: {
        MiscState.qsOpen = showQsPopup;
        if (!showQsPopup) {
            showPowerPopup = false;
            timerPicker = 0;
        }
    }
    Component.onCompleted: MiscState.qsOpen = showQsPopup

    onRightClicked: MiscState.toggleSysTray = !MiscState.toggleSysTray
    onAltLeftClicked: MiscState.toggleSysTray = !MiscState.toggleSysTray

    Shortcut {
        sequence: "Escape"
        enabled: root.showQsPopup
        onActivated: root.showQsPopup = false
    }

    content: NixIcon {}

    PopupWindow {
        id: quickSettingsPopup
        visible: root.showQsPopup
        grabFocus: true
        color: MiscState.popupSolidBg ? "#282a36" : "transparent"

        anchor.window: root.host
        anchor.rect.x: {
            let g = root.mapToGlobal(0, 0);
            return g.x + (root.width / 2) - (width / 2);
        }
        anchor.rect.y: 33

        implicitWidth: 340
        implicitHeight: Math.min(qsContent.implicitHeight + 16, Screen.desktopAvailableHeight * 0.7)

        Rectangle {
            anchors.fill: parent
            radius: 12
            layer.enabled: true
            layer.samples: 8
            color: "#282a36"
            border.color: "#44475a"

            Shortcut {
                sequence: "Escape"
                onActivated: root.showQsPopup = false
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.showQsPopup = false
                z: -1
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    id: qsContent
                    width: parent.width
                    spacing: 0

                    // ═══ CONTENT ═══
                    ColumnLayout {
                        id: contentCol
                        Layout.fillWidth: true
                        spacing: 0

                        // ═══ HEADER ═══
                        Card {
                            title: ""
                            icon: ""
                            accent: "transparent"
                            cardColor: "transparent"
                            cardPadding: 8
                            // cardPadding: 0
                            // x: 0

                            content: RowLayout {
                                id: headerBeforeCards
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    spacing: 2

                                    StyledText {
                                        text: root.hostName
                                        horizontalAlignment: Text.AlignLeft
                                        font {
                                            pixelSize: 13
                                            family: "Quicksand"
                                            bold: true
                                        }
                                        color: "#f8f8f2"
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        text: ResourcesState.uptimeText
                                        visible: text.length > 0
                                        horizontalAlignment: Text.AlignLeft
                                        font {
                                            pixelSize: 12
                                            family: "Monofur Nerd Font"
                                            weight: Font.Bold
                                        }
                                        color: "#b8bfcb"
                                        elide: Text.ElideRight
                                    }
                                }

                                // gap between the identity block and the control icons
                                Item {
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    id: controls
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignRight
                                    radius: 6
                                    color: caffeineMouse.containsMouse ? Qt.rgba(0.98, 0.70, 0.53, 0.15) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: CaffeineService.enabled ? "" : "󰾪"
                                        color: CaffeineService.enabled ? "#ffb86c" : "#6272a4"
                                        font {
                                            pixelSize: 16
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    MouseArea {
                                        id: caffeineMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: CaffeineService.toggle()
                                    }
                                }

                                Rectangle {
                                    id: nasBtn

                                    // NAS remount shortcut only makes sense on carthage
                                    visible: root.hostName === "carthage"
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 6
                                    // grey when everything is mounted, orange when a NAS share is missing;
                                    // bg + border only appear on hover
                                    color: !nasBtnMouse.containsMouse ? "transparent" : root.nasAllMounted ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 0.72, 0.42, 0.16)
                                    border.width: nasBtnMouse.containsMouse ? 1 : 0
                                    border.color: root.nasAllMounted ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 0.72, 0.42, 0.35)

                                    Text {
                                        anchors.centerIn: parent
                                        // text: "\uf4a6"
                                        text: "\uf4a6"
                                        color: {
                                            if (root.nasAllMounted)
                                                return nasBtnMouse.containsMouse ? "#9aa3b2" : "#6272a4";
                                            return nasBtnMouse.containsMouse ? "#ffd9a8" : "#ffb86c";
                                        }
                                        font {
                                            pixelSize: 16
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    MouseArea {
                                        id: nasBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(["sh", "-c", "for m in Hyogo Mutsu Yuri; do systemctl is-active \"media-$m.mount\" >/dev/null 2>&1 || systemctl restart \"media-$m.mount\"; done"]);
                                            root.nasAllMounted = true;
                                            nasRecheck.restart();
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 6
                                    color: settingsBtnMouse.containsMouse ? Qt.rgba(0.54, 0.57, 0.96, 0.15) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: "#bd93f9"
                                        font {
                                            pixelSize: 16
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    MouseArea {
                                        id: settingsBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.showQsPopup = false;
                                            MiscState.toggleSettings = true;
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 6
                                    color: powerBtnMouse.containsMouse ? Qt.rgba(0.95, 0.55, 0.66, 0.15) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: root.showPowerPopup ? "#ff5555" : "#6272a4"
                                        font {
                                            pixelSize: 16
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    MouseArea {
                                        id: powerBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showPowerPopup = !root.showPowerPopup
                                    }
                                }
                            }
                        }

                        // ═══ POWER ═══
                        Card {
                            title: ""
                            icon: ""
                            visible: root.showPowerPopup
                            Layout.topMargin: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Layout.preferredHeight: 42

                                QsPower {
                                    icon: ""
                                    color: "#bd93f9"
                                    label: "Lock"
                                    cmd: "hyprlock"
                                }
                                QsPower {
                                    icon: "󱫭"
                                    color: "#50fa7b"
                                    label: PowerTimer.mode === "reboot" ? PowerTimer.formatTime(PowerTimer.remaining) : "R-Timer"
                                    highlighted: PowerTimer.mode === "reboot"
                                    cmd: ""
                                    onActivated: root.timerPicker = root.timerPicker === 1 ? 0 : 1
                                }
                                QsPower {
                                    icon: ""
                                    // color: "#f1fa8c"
                                    color: "#50fa7b"
                                    label: "Reboot"
                                    cmd: "systemctl reboot"
                                }
                                QsPower {
                                    icon: "󱫖"
                                    color: "#ff5555"
                                    // color: "#ff79c6"
                                    label: PowerTimer.mode === "poweroff" ? PowerTimer.formatTime(PowerTimer.remaining) : "S-Timer"
                                    highlighted: PowerTimer.mode === "poweroff"
                                    cmd: ""
                                    onActivated: root.timerPicker = root.timerPicker === 2 ? 0 : 2
                                }
                                QsPower {
                                    icon: ""
                                    color: "#ff5555"
                                    label: "Off"
                                    cmd: "systemctl poweroff"
                                }
                                QsPower {
                                    icon: ""
                                    color: "#bd93f9"
                                    label: "Exit"
                                    cmd: "loginctl terminate-user $USER"
                                }
                            }
                        }

                        // ═══ TIMER PRESETS ═══
                        Card {
                            id: timerCard

                            title: ""
                            icon: ""
                            visible: root.timerPicker !== 0
                            Layout.topMargin: -4
                            cardPadding: 8

                            readonly property string modeName: root.timerPicker === 1 ? "Reboot" : "Shutdown"

                            function pick(minutes) {
                                if (root.timerPicker === 1)
                                    PowerTimer.scheduleReboot(minutes * 60);
                                else if (root.timerPicker === 2)
                                    PowerTimer.schedulePoweroff(minutes * 60);
                                root.timerPicker = 0;
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    readonly property bool live: PowerTimer.active && PowerTimer.mode === (root.timerPicker === 1 ? "reboot" : "poweroff")
                                    text: live ? timerCard.modeName + " in " + PowerTimer.formatTime(PowerTimer.remaining) : timerCard.modeName + " after:"
                                    color: live ? (root.timerPicker === 1 ? "#50fa7b" : "#ff5555") : "#6272a4"
                                    font {
                                        pixelSize: 9
                                        bold: true
                                        family: "Quicksand"
                                        letterSpacing: 1
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    TimerChip {
                                        txt: "5m"
                                        onPicked: timerCard.pick(5)
                                    }
                                    TimerChip {
                                        txt: "15m"
                                        onPicked: timerCard.pick(15)
                                    }
                                    TimerChip {
                                        txt: "30m"
                                        onPicked: timerCard.pick(30)
                                    }
                                    TimerChip {
                                        txt: "1h"
                                        onPicked: timerCard.pick(60)
                                    }
                                    TimerChip {
                                        txt: "2h"
                                        onPicked: timerCard.pick(120)
                                    }
                                }

                                TimerChip {
                                    visible: PowerTimer.active
                                    txt: "cancel " + (PowerTimer.mode === "reboot" ? "reboot" : "shutdown") + " · " + PowerTimer.formatTime(PowerTimer.remaining)
                                    danger: true
                                    onPicked: {
                                        PowerTimer.cancel();
                                        root.timerPicker = 0;
                                    }
                                }
                            }
                        }

                        // ═══ NOW PLAYING ═══
                        ClippingRectangle {
                            id: nowPlayingCard
                            Layout.fillWidth: true
                            Layout.bottomMargin: 6
                            radius: 10
                            visible: MprisState.player !== null
                            color: {
                                if (MprisState.player?.trackArtUrl)
                                    return Qt.rgba(nowPlayingCard.dominantColor.r, nowPlayingCard.dominantColor.g, nowPlayingCard.dominantColor.b, 0.12);
                                return "#21222c";
                            }
                            implicitHeight: root.compactNowPlaying ? 82 : 260
                            Behavior on implicitHeight {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }

                            property color dominantColor: "#bd93f9"
                            border {
                                width: 1
                                color: Qt.rgba(nowPlayingCard.dominantColor.r, nowPlayingCard.dominantColor.g, nowPlayingCard.dominantColor.b, 0.35)
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 300
                                }
                            }

                            property int progressTick: 0
                            property bool showVolumeBadge: false
                            readonly property int currentVolume: Math.round((MprisState.player?.volume ?? 0) * 100)

                            Timer {
                                id: volumeBadgeTimer
                                interval: 800
                                running: false
                                repeat: false
                                onTriggered: nowPlayingCard.showVolumeBadge = false
                            }

                            // ── Hidden helpers ──
                            Item {
                                visible: false
                                width: 0
                                height: 0

                                Image {
                                    id: hiddenArt
                                    source: MprisState.player?.trackArtUrl || ""
                                    asynchronous: true
                                    onStatusChanged: {
                                        if (status === Image.Ready)
                                            colorSampler.requestPaint();
                                        else if (status === Image.Null || status === Image.Error)
                                            nowPlayingCard.dominantColor = "#bd93f9";
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
                                            nowPlayingCard.dominantColor = Qt.rgba(r, g, b, 1.0);
                                        } catch (e) {}
                                    }
                                }

                                Timer {
                                    interval: 1000
                                    running: MprisState.player?.isPlaying ?? false
                                    repeat: true
                                    onTriggered: nowPlayingCard.progressTick++
                                }
                            }

                            // ── COMPACT VIEW ──
                            Item {
                                visible: root.compactNowPlaying
                                anchors.fill: parent

                                // TODO: have trackbutton here
                                TrackButton {
                                    text: "+"
                                    ghost: true
                                    // accentColor: "#6272a4"
                                    accentColor: nowPlayingCard.color
                                    onClicked: root.compactNowPlaying = false
                                    // Layout.rightMargin: 4
                                    anchors {
                                        right: parent.right
                                        top: parent.top
                                        rightMargin: 2
                                        topMargin: 2
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
                                        color: compactArtImage.status === Image.Ready ? Qt.rgba(nowPlayingCard.dominantColor.r, nowPlayingCard.dominantColor.g, nowPlayingCard.dominantColor.b, 0.15) : "#343746"

                                        border {
                                            width: compactArtImage.status === Image.Ready ? 1 : 0
                                            color: Qt.rgba(nowPlayingCard.dominantColor.r, nowPlayingCard.dominantColor.g, nowPlayingCard.dominantColor.b, 0.2)
                                        }

                                        Image {
                                            id: compactArtImage
                                            anchors.fill: parent
                                            source: MprisState.player?.trackArtUrl || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            mipmap: true
                                            visible: status === Image.Ready && !nowPlayingCard.showVolumeBadge
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            color: "#6272a4"
                                            font {
                                                pixelSize: 24
                                                family: "Symbols Nerd Font Mono"
                                            }
                                            visible: compactArtImage.status !== Image.Ready && !nowPlayingCard.showVolumeBadge
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: nowPlayingCard.currentVolume
                                            // color: "#ffffff"
                                            color: nowPlayingCard.dominantColor
                                            // style: Text.Raised
                                            // styleColor: Qt.rgba(0, 0, 0, 0.55)
                                            font {
                                                pixelSize: 19
                                                bold: true
                                                family: "monofur Nerd Font"
                                            }
                                            visible: nowPlayingCard.showVolumeBadge
                                        }
                                    }

                                    // ── Info panel ──
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 2

                                        // ── Title + row ──
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 4

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: MprisState.player?.trackTitle || "No track"
                                                    color: "#f8f8f2"
                                                    font {
                                                        pixelSize: 11
                                                        bold: true
                                                        family: "Quicksand"
                                                    }
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: MprisState.player?.trackArtist || ""
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
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 6
                                            Layout.rightMargin: 6

                                            readonly property real ratio: {
                                                nowPlayingCard.progressTick;
                                                var p = MprisState.player;
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
                                                height: 3
                                                radius: 1.5
                                                color: Qt.rgba(1, 1, 1, 0.08)

                                                Rectangle {
                                                    width: parent.width * parent.parent.ratio
                                                    height: parent.height
                                                    radius: 1.5
                                                    color: nowPlayingCard.dominantColor
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
                                                    var p = MprisState.player;
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
                                                accentColor: nowPlayingCard.dominantColor
                                                onClicked: MprisState.player?.previous()
                                            }
                                            TrackButton {
                                                text: MprisState.player?.isPlaying ? "\uf04c" : "\uf04b"
                                                flat: true
                                                accentColor: nowPlayingCard.dominantColor
                                                onClicked: MprisState.player?.togglePlaying()
                                            }
                                            TrackButton {
                                                text: "\uf050"
                                                flat: true
                                                accentColor: nowPlayingCard.dominantColor
                                                onClicked: MprisState.player?.next()
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
                                visible: !root.compactNowPlaying
                                anchors.fill: parent
                                // implicitHeight: 100
                                // implicitWidth: 100

                                // ── Album art background ──
                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: {
                                        if (MprisState.player?.trackArtUrl)
                                            return Qt.rgba(nowPlayingCard.dominantColor.r, nowPlayingCard.dominantColor.g, nowPlayingCard.dominantColor.b, 0.12);
                                        return "#21222c";
                                    }

                                    Image {
                                        id: expandedArtImage
                                        anchors.fill: parent
                                        source: MprisState.player?.trackArtUrl || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
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
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 6

                                    // ── Top bar ──
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            visible: MiscState.showPlayerChooser
                                            implicitHeight: 20
                                            radius: height / 2
                                            color: Qt.rgba(0, 0, 0, 0.35)
                                            Layout.preferredWidth: expPill.implicitWidth + 16

                                            RowLayout {
                                                id: expPill
                                                anchors.fill: parent
                                                anchors.leftMargin: 7
                                                anchors.rightMargin: 7
                                                spacing: 4
                                                Rectangle {
                                                    implicitWidth: 5
                                                    implicitHeight: 5
                                                    radius: 2.5
                                                    color: MprisState.player?.isPlaying ? "#88FF00" : "#6272a4"
                                                }
                                                Text {
                                                    text: MprisState.player?.identity || ""
                                                    color: "#f8f8f2"
                                                    font {
                                                        pixelSize: 7
                                                        family: "FantasqueSansM Nerd Font"
                                                        bold: true
                                                    }
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: playerListOpen = !playerListOpen
                                            }
                                        }

                                        Text {
                                            visible: MiscState.showPlayerChooser
                                            text: Mpris.players.length + " player(s)"
                                            color: "#6272a4"
                                            font {
                                                pixelSize: 7
                                                family: "ZedMono Nerd Font"
                                            }
                                            Layout.rightMargin: 24
                                        }
                                    }

                                    Item {
                                        Layout.fillHeight: true
                                    }

                                    // ── Track info ──
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3
                                        Layout.leftMargin: 4
                                        Layout.rightMargin: 4

                                        Text {
                                            Layout.fillWidth: true
                                            text: MprisState.player?.trackTitle || "No track"
                                            color: "#ffffff"
                                            font {
                                                bold: true
                                                pixelSize: 18
                                                family: "FantasqueSansM Nerd Font"
                                            }
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            style: Text.Raised
                                            styleColor: Qt.rgba(0, 0, 0, 0.7)
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: MprisState.player?.trackArtist || ""
                                            color: Qt.rgba(1, 1, 1, 0.7)
                                            font {
                                                pixelSize: 12
                                                family: "ZedMono Nerd Font"
                                            }
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            visible: text.length > 0
                                        }
                                    }

                                    // ── Progress bar ──
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 16
                                        Layout.topMargin: 2

                                        readonly property real ratio: {
                                            nowPlayingCard.progressTick;
                                            var p = MprisState.player;
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
                                                color: nowPlayingCard.dominantColor
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
                                                var p = MprisState.player;
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
                                        Layout.bottomMargin: 2

                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        TrackButton {
                                            text: ""
                                            visible: MiscState.showShuffle
                                            active: MprisState.player?.shuffle ?? false
                                            accentColor: MprisState.player?.shuffle ? "#f1fa8c" : Qt.rgba(1, 1, 1, 0.6)
                                            onClicked: {
                                                var p = MprisState.player;
                                                if (p?.canControl && p?.shuffleSupported)
                                                    p.shuffle = !p.shuffle;
                                            }
                                        }
                                        TrackButton {
                                            text: ""
                                            accentColor: Qt.rgba(1, 1, 1, 0.8)
                                            onClicked: MprisState.player?.previous()
                                        }
                                        TrackButton {
                                            text: MprisState.player?.isPlaying ? "" : ""
                                            accentColor: "#ffffff"
                                            onClicked: MprisState.player?.togglePlaying()
                                        }
                                        TrackButton {
                                            text: ""
                                            accentColor: Qt.rgba(1, 1, 1, 0.8)
                                            onClicked: MprisState.player?.next()
                                        }
                                        TrackButton {
                                            text: ""
                                            visible: MiscState.showLoop
                                            active: MprisState.player?.loopState !== MprisLoopState.None
                                            accentColor: MprisState.player?.loopState === MprisLoopState.Track ? "#f1fa8c" : MprisState.player?.loopState === MprisLoopState.Playlist ? "#bd93f9" : Qt.rgba(1, 1, 1, 0.6)
                                            onClicked: {
                                                var p = MprisState.player;
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

                                TrackButton {
                                    text: "−"
                                    ghost: true
                                    accentColor: Qt.rgba(1, 1, 1, 0.6)
                                    onClicked: root.compactNowPlaying = true
                                    anchors {
                                        right: parent.right
                                        top: parent.top
                                        rightMargin: 2
                                        topMargin: 2
                                    }
                                }
                            }

                            // ── Volume HUD (bottom-left of card) ──
                            Rectangle {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                implicitWidth: cardOsdRow.implicitWidth + 20
                                implicitHeight: 24
                                radius: 12
                                color: Qt.rgba(0, 0, 0, 0.72)
                                border.width: 1
                                border.color: Qt.rgba(nowPlayingCard.dominantColor.r, nowPlayingCard.dominantColor.g, nowPlayingCard.dominantColor.b, 0.35)
                                opacity: root.osdShown && root.osdInCard ? 1 : 0
                                scale: root.osdShown && root.osdInCard ? 1 : 0.85

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                RowLayout {
                                    id: cardOsdRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: root.osdGlyph
                                        color: nowPlayingCard.dominantColor
                                        font {
                                            pixelSize: 11
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    Text {
                                        text: root.osdValue + "%"
                                        color: "#f8f8f2"
                                        font {
                                            pixelSize: 11
                                            bold: true
                                            family: "ZedMono Nerd Font"
                                        }
                                    }
                                }
                            }

                            // ── Mouse area for scroll volume ──
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: wheel => {
                                    var p = MprisState.player;
                                    if (p?.canControl && p?.volumeSupported) {
                                        p.volume = Math.max(0, Math.min(p.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05), 1));
                                        root.showOsd("\uf028", Math.round(p.volume * 100), true);
                                    }
                                }
                            }
                        }

                        // ═══ VOLUME ═══
                        ClippingRectangle {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 6
                            radius: 10
                            color: "#21222c"
                            border.width: 1
                            border.color: Qt.rgba(0.74, 0.58, 0.98, 0.25)
                            implicitHeight: volumeCol.implicitHeight + 20

                            ColumnLayout {
                                id: volumeCol
                                anchors.fill: parent
                                // right strip reserved for the pw-center button
                                anchors.leftMargin: 10
                                anchors.topMargin: 10
                                anchors.bottomMargin: 10
                                anchors.rightMargin: 32
                                spacing: 8

                                Brightness {
                                    Layout.topMargin: 2
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    visible: BrightnessState.available
                                    color: "#343746"
                                }

                                SinkName {
                                    node: PipewireState.outputSink
                                    fallback: "output"
                                    accent: "#bd93f9"
                                    displayName: PipewireState.outputDisplayName
                                }

                                VolumeSlider {
                                    id: outVol
                                    node: PipewireState.outputSink
                                    glyph: "\uf028"
                                    glyphMuted: "\uf026"
                                    accent: "#bd93f9"

                                    onAdjusted: level => root.showOsd("\uf028", Math.round(level * 100))
                                }

                                Item {
                                    Layout.preferredHeight: 2
                                }

                                SinkName {
                                    node: PipewireState.inputSink
                                    fallback: "input"
                                    accent: "#8be9fd"
                                }

                                VolumeSlider {
                                    id: inVol
                                    node: PipewireState.inputSink
                                    glyph: "\uf130"
                                    glyphMuted: "\uf131"
                                    accent: "#8be9fd"

                                    onAdjusted: level => root.showOsd("\uf130", Math.round(level * 100))
                                }
                            }

                            // ── pw management shortcut (hyprpwcenter) ──
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 7
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 5
                                color: pwMouse.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.18) : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf013"
                                    color: pwMouse.containsMouse ? "#bd93f9" : "#6272a4"
                                    font {
                                        pixelSize: 10
                                        family: "Symbols Nerd Font Mono"
                                    }
                                }

                                MouseArea {
                                    id: pwMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.showQsPopup = false;
                                        Quickshell.execDetached(["sh", "-c", "exec hyprpwcenter 2>/dev/null || exec pwvucontrol"]);
                                    }
                                }
                            }

                            // ── Volume OSD ──
                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                implicitWidth: osdRow.implicitWidth + 20
                                implicitHeight: 24
                                radius: 12
                                color: Qt.rgba(0, 0, 0, 0.72)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.09)
                                opacity: root.osdShown && !root.osdInCard ? 1 : 0
                                scale: root.osdShown && !root.osdInCard ? 1 : 0.85

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                RowLayout {
                                    id: osdRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: root.osdGlyph
                                        color: "#bd93f9"
                                        font {
                                            pixelSize: 11
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    Text {
                                        text: root.osdValue + "%"
                                        color: "#f8f8f2"
                                        font {
                                            pixelSize: 11
                                            bold: true
                                            family: "ZedMono Nerd Font"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component TimerChip: Rectangle {
        id: chip

        property string txt
        property bool danger: false
        signal picked()

        Layout.fillWidth: true
        implicitHeight: 24
        radius: 6
        color: {
            if (!mouse.containsMouse)
                return "#343746";
            return danger ? Qt.rgba(1, 0.33, 0.33, 0.15) : Qt.rgba(0.74, 0.58, 0.98, 0.15);
        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            anchors.centerIn: parent
            text: chip.txt
            color: mouse.containsMouse ? (chip.danger ? "#ff5555" : "#bd93f9") : "#b8bfcb"
            font {
                pixelSize: 9
                bold: true
                family: "Quicksand"
                letterSpacing: 1
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.picked()
        }
    }

    component SinkName: RowLayout {
        required property PwNode node
        required property string fallback
        required property color accent
        property string displayName

        Layout.fillWidth: true
        spacing: 6

        Text {
            text: {
                if (parent.displayName && parent.displayName.length > 0)
                    return parent.displayName;
                const d = parent.node?.description;
                return d && d.length > 0 ? d : parent.fallback;
            }
            color: parent.accent
            elide: Text.ElideRight
            font {
                pixelSize: 10
                bold: true
                family: "Quicksand"
                letterSpacing: 1
            }
            Layout.fillWidth: true
        }

        Text {
            visible: parent.node === null
            text: "unavailable"
            color: "#6272a4"
            font {
                pixelSize: 9
                family: "ZedMono Nerd Font"
            }
        }
    }
}
