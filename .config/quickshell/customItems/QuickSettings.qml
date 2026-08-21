import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets

import qs.customItems
import qs.customItems.quicksettings
import qs.services
import qs.themes

BarBlock {
    id: root

    required property var host

    property string hostName: QuickState.hostName

    property bool playerListOpen: false
    property bool showQsPopup: false
    property bool showPowerPopup: false
    property bool compactNowPlaying: true
    property bool shuffleOn: false
    property bool loopOn: false

    onLeftClicked: {
        root.showQsPopup = !root.showQsPopup;
    }

    onMiddleClicked: MiscState.toggleVolume = !MiscState.toggleVolume
    onRightClicked: MiscState.toggleSysTray = !MiscState.toggleSysTray
    onAltLeftClicked: MiscState.toggleSysTray = !MiscState.toggleSysTray

    Shortcut {
        sequence: "Escape"
        enabled: root.showQsPopup
        onActivated: root.showQsPopup = false
    }

    content: Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: ""
            color: "#cba6f7"
            font {
                pixelSize: 16
                family: "Symbols Nerd Font Mono"
            }
        }
    }

    PopupWindow {
        id: qsPopup
        visible: root.showQsPopup
        grabFocus: true
        color: MiscState.popupSolidBg ? "#1e1e2e" : "transparent"

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
            color: "#1e1e2e"
            border.color: "#45475a"

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
                                    Layout.fillWidth: true

                                    Text {
                                        visible: false
                                        text: root.hostName
                                        color: "#cdd6f4"
                                        font {
                                            pixelSize: 13
                                            family: "Quicksand"
                                            bold: true
                                        }
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
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
                                        color: CaffeineService.enabled ? "#fab387" : "#585b70"
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
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 6
                                    color: nasBtnMouse.containsMouse ? Qt.rgba(0.66, 0.84, 0.72, 0.15) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        // text: "\uf4a6"
                                        text: ""
                                        color: "pink"
                                        font {
                                            pixelSize: 16
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    MouseArea {
                                        id: nasBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["sh", "-c", "for m in Hyogo Mutsu Yuri; do systemctl is-active \"media-$m.mount\" >/dev/null 2>&1 || systemctl restart \"media-$m.mount\"; done"])
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
                                        color: "#89b4fa"
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
                                        color: root.showPowerPopup ? "#f38ba8" : "#585b70"
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
                                    color: "#89b4fa"
                                    label: "Lock"
                                    cmd: "hyprlock"
                                }
                                QsPower {
                                    icon: "󱫭"
                                    color: "#a6e3a1"
                                    label: "R-Timer"
                                    cmd: "notify-send 'future suspend'"
                                }
                                QsPower {
                                    icon: ""
                                    // color: "#f9e2af"
                                    color: "#a6e3a1"
                                    label: "Reboot"
                                    cmd: "systemctl reboot"
                                }
                                QsPower {
                                    icon: "󱫖"
                                    color: "#f38ba8"
                                    // color: "#f5c2e7"
                                    label: "S-Timer"
                                    cmd: "notify-send 'future shutdown'"
                                }
                                QsPower {
                                    icon: ""
                                    color: "#f38ba8"
                                    label: "Off"
                                    cmd: "systemctl poweroff"
                                }
                                QsPower {
                                    icon: ""
                                    color: "#cba6f7"
                                    label: "Exit"
                                    cmd: "loginctl terminate-user $USER"
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
                                return "#181825";
                            }
                            implicitHeight: root.compactNowPlaying ? 82 : 260
                            Behavior on implicitHeight {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }

                            property color dominantColor: "#cba6f7"
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
                                            nowPlayingCard.dominantColor = "#cba6f7";
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
                                    // accentColor: "#585b70"
                                    accentColor: nowPlayingCard.color
                                    onClicked: root.compactNowPlaying = false
                                    // Layout.rightMargin: 4
                                    anchors {
                                        right: parent.right
                                        top: parent.top
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
                                        color: compactArtImage.status === Image.Ready ? Qt.rgba(nowPlayingCard.dominantColor.r, nowPlayingCard.dominantColor.g, nowPlayingCard.dominantColor.b, 0.15) : "#313244"

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
                                            color: "#585b70"
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
                                                    color: "#cdd6f4"
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
                                                    color: "#a6adc8"
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
                                        return "#181825";
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
                                        color: "#585b70"
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
                                                    color: MprisState.player?.isPlaying ? "#88FF00" : "#585b70"
                                                }
                                                Text {
                                                    text: MprisState.player?.identity || ""
                                                    color: "#cdd6f4"
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
                                            color: "#585b70"
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
                                            accentColor: MprisState.player?.shuffle ? "#f9e2af" : Qt.rgba(1, 1, 1, 0.6)
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
                                            accentColor: MprisState.player?.loopState === MprisLoopState.Track ? "#f9e2af" : MprisState.player?.loopState === MprisLoopState.Playlist ? "#89b4fa" : Qt.rgba(1, 1, 1, 0.6)
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
                                    accentColor: Qt.rgba(1, 1, 1, 0.6)
                                    onClicked: root.compactNowPlaying = true
                                    anchors {
                                        right: parent.right
                                        top: parent.top
                                    }
                                }
                            }

                            // ── Volume badge (shows on scroll, expanded only) ──
                            Rectangle {
                                anchors.centerIn: parent
                                implicitWidth: 60
                                implicitHeight: 36
                                radius: 8
                                visible: !root.compactNowPlaying
                                color: Qt.rgba(0, 0, 0, 0.75)
                                opacity: nowPlayingCard.showVolumeBadge ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: nowPlayingCard.currentVolume + "%"
                                    color: "#ffffff"
                                    font {
                                        pixelSize: 14
                                        bold: true
                                        family: "Quicksand"
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
                                        nowPlayingCard.showVolumeBadge = true;
                                        volumeBadgeTimer.restart();
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
