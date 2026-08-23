import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
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

    property bool playerListOpen: false // reserved for a future chooser popup
    property bool showQsPopup: false
    property bool showPowerPopup: false
    // 0 = hidden, 1 = reboot presets, 2 = shutdown presets
    property int timerPicker: 0
    property bool compactNowPlaying: true
    property bool shuffleOn: false
    property bool loopOn: false

    // true while every NAS share (Hyogo/Mutsu/Yuri) is mounted.
    // parsed straight from /proc/mounts — no subprocess spawns per refresh
    property bool nasAllMounted: true

    function checkNasShares() {
        const t = nasMounts.text();
        root.nasAllMounted = t.includes("/Hyogo") && t.includes("/Mutsu") && t.includes("/Yuri");
    }

    FileView {
        id: nasMounts
        path: "/proc/mounts"

        onInternalTextChanged: root.checkNasShares()
    }

    // background refresh — only polled while the popup is open (the NAS state
    // lives on that button); a fresh read happens on open so it's never stale
    Timer {
        interval: 10000
        running: root.showQsPopup
        repeat: true
        triggeredOnStart: true
        onTriggered: nasMounts.reload()
    }
    Timer {
        id: nasRecheck
        // fast re-poll after a remount click so the button color recovers quickly
        interval: 2000
        running: false
        repeat: true
        onTriggered: {
            if (root.nasAllMounted)
                stop();
            else
                nasMounts.reload();
        }
    }

    // ── volume OSD ──
    onLeftClicked: {
        root.showQsPopup = !root.showQsPopup;
    }

    onShowQsPopupChanged: {
        MiscState.qsOpen = showQsPopup;
        if (!showQsPopup) {
            showPowerPopup = false;
            timerPicker = 0;
        } else {
            nasMounts.reload();
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

    content: NixQuickSettings {}

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

        // +24 for the shadow gutter around the card
        implicitWidth: 364
        implicitHeight: Math.min(qsContent.implicitHeight + 36, Screen.desktopAvailableHeight * 0.7)

        // drop shadow drawn from a proxy silhouette so the real card never
        // passes through the effect (stays pixel-crisp and fully interactive)
        MultiEffect {
            anchors.fill: parent
            source: shadowProxy
            shadowEnabled: true
            shadowBlur: 0.85
            shadowColor: Qt.rgba(0, 0, 0, 0.6)
            shadowVerticalOffset: 5
        }

        Rectangle {
            id: shadowProxy
            anchors.fill: parent
            anchors.margins: 12
            radius: 12
            visible: false
            color: "#282a36"
        }

        Rectangle {
            id: qsCard
            anchors.fill: parent
            anchors.margins: 12
            radius: 12
            color: "#282a36"

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
                anchors.margins: 3
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

                                // avatar — click to choose a new one
                                ClippingRectangle {
                                    id: avatarBox
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    radius: height / 2
                                    color: avatarMa.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.18) : "#343746"

                                    Image {
                                        id: avatarImg
                                        anchors.fill: parent
                                        source: MiscState.avatarUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf007"
                                        color: "#6272a4"
                                        font { pixelSize: 16; family: "Symbols Nerd Font Mono" }
                                        visible: avatarImg.status !== Image.Ready
                                    }

                                    MouseArea {
                                        id: avatarMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: MiscState.pickAvatar()
                                    }
                                }

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

                                // utility cluster — power stays put; hovering it
                                // slides the rest of the row out to its left
                                Item {
                                    id: ctrlCluster

                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignRight
                                    implicitWidth: revealGroup.width + 10 + 32
                                    width: ctrlCluster.revealed ? implicitWidth : 32
                                    clip: true

                                    // stays open while a popup card is up so the row doesn't slam shut
                                    readonly property bool revealed: clusterHover.hovered || root.showPowerPopup

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    HoverHandler {
                                        id: clusterHover
                                    }

                                    // the hover-revealed buttons — fade + slide as one unit
                                    Item {
                                        id: revealGroup

                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: ctrlCluster.revealed ? hiddenRow.implicitWidth : 0
                                        height: 32
                                        clip: true
                                        opacity: ctrlCluster.revealed ? 1 : 0

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 200
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 150
                                            }
                                        }

                                        RowLayout {
                                            id: hiddenRow

                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 10

                                            Rectangle {
                                                id: controls

                                                Layout.preferredWidth: 32
                                                Layout.preferredHeight: 32
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
                                        }
                                    }

                                    // power — always visible on the right edge
                                    Rectangle {

                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 32
                                        height: 32
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
                                    icon: ""
                                    color: "#50fa7b"
                                    label: PowerTimer.mode === "reboot" ? PowerTimer.formatTime(PowerTimer.remaining) : "Reboot"
                                    highlighted: PowerTimer.mode === "reboot"
                                    cmd: ""
                                    onActivated: root.timerPicker = root.timerPicker === 1 ? 0 : 1
                                }
                                QsPower {
                                    icon: "\uf011"
                                    color: "#ff5555"
                                    label: PowerTimer.mode === "poweroff" ? PowerTimer.formatTime(PowerTimer.remaining) : "Shutdown"
                                    highlighted: PowerTimer.mode === "poweroff"
                                    cmd: ""
                                    onActivated: root.timerPicker = root.timerPicker === 2 ? 0 : 2
                                }
                                QsPower {
                                    icon: "\uf08b"
                                    color: "#bd93f9"
                                    label: "Exit"
                                    cmd: "loginctl terminate-user $USER"
                                }
                            }
                        }


                        // ═══ REBOOT / SHUTDOWN MENU ═══
                        Card {
                            id: timerCard

                            title: ""
                            icon: ""
                            visible: root.timerPicker !== 0
                            Layout.topMargin: -4
                            cardPadding: 8

                            readonly property bool isReboot: root.timerPicker === 1
                            readonly property string modeName: isReboot ? "Reboot" : "Shutdown"
                            // a matching timer is armed; menu stays open as live confirmation
                            readonly property bool live: PowerTimer.active && PowerTimer.mode === (isReboot ? "reboot" : "poweroff")

                            function pick(minutes) {
                                if (minutes <= 0) {
                                    root.showQsPopup = false;
                                    Quickshell.execDetached(["systemctl", isReboot ? "reboot" : "poweroff"]);
                                    return;
                                }
                                if (isReboot)
                                    PowerTimer.scheduleReboot(minutes * 60);
                                else
                                    PowerTimer.schedulePoweroff(minutes * 60);
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    text: timerCard.live ? timerCard.modeName + " in " + PowerTimer.formatTime(PowerTimer.remaining) : timerCard.modeName + " after:"
                                    color: timerCard.live ? (timerCard.isReboot ? "#50fa7b" : "#ff5555") : "#6272a4"
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
                                        txt: "now"
                                        danger: true
                                        onPicked: timerCard.pick(0)
                                    }
                                    TimerChip {
                                        txt: "5m"
                                        onPicked: timerCard.pick(5)
                                    }
                                    TimerChip {
                                        txt: "10m"
                                        onPicked: timerCard.pick(10)
                                    }
                                    TimerChip {
                                        txt: "15m"
                                        onPicked: timerCard.pick(15)
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

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
                                    TimerChip {
                                        txt: "4h"
                                        onPicked: timerCard.pick(240)
                                    }
                                }

                                TimerChip {
                                    visible: timerCard.live
                                    txt: "cancel " + (PowerTimer.mode === "reboot" ? "reboot" : "shutdown") + " · " + PowerTimer.formatTime(PowerTimer.remaining)
                                    danger: true
                                    onPicked: PowerTimer.cancel()
                                }
                            }
                        }

                        // ═══ NOW PLAYING ═══
                        ClippingRectangle {
                            id: nowPlayingCard
                            Layout.fillWidth: true
                            Layout.bottomMargin: 6
                            radius: 10
                            visible: MprisState.cardPlayer !== null
                            color: {
                                if (MprisState.cardPlayer?.trackArtUrl)
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
                            // external players (no MPRIS volume, e.g. chrome) get a
                            // locally tracked percentage since pactl can't be read back
                            property real extVol: 0.5
                            readonly property bool mprisVolume: MprisState.cardPlayer?.volumeSupported ?? false
                            readonly property int currentVolume: Math.round((mprisVolume ? MprisState.cardPlayer?.volume ?? 0 : extVol) * 100)

                            // visibility-first volume tint — hotter as it gets louder
                            readonly property color volumeColor: currentVolume <= 0 ? "#6272a4"
                                : currentVolume > 80 ? "#ff79c6"
                                : currentVolume > 50 ? "#c6a0f6"
                                : "#bd93f9"

                            Timer {
                                id: volumeBadgeTimer
                                interval: 800
                                running: false
                                repeat: false
                                onTriggered: nowPlayingCard.showVolumeBadge = false
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
                                    if (nowPlayingCard.mprisVolume) {
                                        MprisState.adjustVolume(p, ev.angleDelta.y > 0);
                                    } else {
                                        nowPlayingCard.extVol = Math.max(0, Math.min(nowPlayingCard.extVol + (ev.angleDelta.y > 0 ? 0.05 : -0.05), 1));
                                        MprisState.adjustVolume(p, ev.angleDelta.y > 0);
                                    }
                                    nowPlayingCard.showVolumeBadge = true;
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
                                    running: MprisState.cardPlayer?.isPlaying ?? false
                                    repeat: true
                                    onTriggered: nowPlayingCard.progressTick++
                                }
                            }

                            // ── COMPACT VIEW ──
                            Item {
                                id: compactView
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

                                // player switcher — glyph shows the app in control;
                                // click cycles, right-click jumps to the first playing player
                                TrackButton {
                                    id: compactSwitcher

                                    // small and unobtrusive — brightens on hover
                                    z: 10
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    opacity: swCompactHover.hovered ? 1 : 0.5
                                    text: MprisState.appGlyph(MprisState.cardPlayer)
                                    ghost: true
                                    accentColor: MprisState.pinIdentity.length > 0 ? "#f1fa8c" : Qt.rgba(1, 1, 1, 0.6)
                                    onClicked: MprisState.cycleCardPin()
                                    anchors {
                                        right: parent.right
                                        bottom: parent.bottom
                                        rightMargin: 6
                                        bottomMargin: 6
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: MprisState.jumpToPlaying()
                                    }
                                }

                                    HoverHandler {
                                        id: swCompactHover
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
                                            source: MprisState.artFor(MprisState.cardPlayer)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            mipmap: true
                                            visible: status === Image.Ready
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: MprisState.isBrowserPlayer(MprisState.cardPlayer) ? MprisState.browserGlyph(MprisState.cardPlayer) : ""
                                            color: "#6272a4"
                                            font {
                                                pixelSize: 24
                                                family: "Symbols Nerd Font Mono"
                                            }
                                            visible: compactArtImage.status !== Image.Ready
                                        }

                                        // ── volume HUD — value only, scrimmed over the art ──
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: Qt.rgba(0, 0, 0, 0.55)
                                            border.width: 1
                                            border.color: Qt.rgba(nowPlayingCard.volumeColor.r, nowPlayingCard.volumeColor.g, nowPlayingCard.volumeColor.b, 0.5)
                                            visible: nowPlayingCard.showVolumeBadge
                                            opacity: visible ? 1 : 0
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 140
                                                    easing.type: Easing.OutQuad
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: `${nowPlayingCard.currentVolume}%`
                                                color: nowPlayingCard.volumeColor
                                                font {
                                                    pixelSize: 17
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
                                                nowPlayingCard.progressTick;
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
                                                    color: nowPlayingCard.dominantColor

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
                                                border.color: nowPlayingCard.dominantColor

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
                                                accentColor: nowPlayingCard.dominantColor
                                                onClicked: MprisState.cardPlayer?.previous()
                                            }
                                            TrackButton {
                                                text: MprisState.cardPlayer?.isPlaying ? "\uf04c" : "\uf04b"
                                                flat: true
                                                accentColor: nowPlayingCard.dominantColor
                                                onClicked: MprisState.cardPlayer?.togglePlaying()
                                            }
                                            TrackButton {
                                                text: "\uf050"
                                                flat: true
                                                accentColor: nowPlayingCard.dominantColor
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
                                visible: !root.compactNowPlaying
                                anchors.fill: parent
                                // implicitHeight: 100
                                // implicitWidth: 100

                                // ── Album art background ──
                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: {
                                        if (MprisState.artFor(MprisState.cardPlayer).length > 0)
                                            return Qt.rgba(nowPlayingCard.dominantColor.r, nowPlayingCard.dominantColor.g, nowPlayingCard.dominantColor.b, 0.12);
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
                                        text: MprisState.isBrowserPlayer(MprisState.cardPlayer) ? MprisState.browserGlyph(MprisState.cardPlayer) : ""
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
                                            text: MprisState.cardPlayer?.trackTitle || "No track"
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
                                            text: MprisState.cardPlayer?.trackArtist || ""
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
                                        Layout.bottomMargin: 2

                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        TrackButton {
                                            text: ""
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
                                            text: ""
                                            accentColor: Qt.rgba(1, 1, 1, 0.8)
                                            onClicked: MprisState.cardPlayer?.previous()
                                        }
                                        TrackButton {
                                            text: MprisState.cardPlayer?.isPlaying ? "" : ""
                                            accentColor: "#ffffff"
                                            onClicked: MprisState.cardPlayer?.togglePlaying()
                                        }
                                        TrackButton {
                                            text: ""
                                            accentColor: Qt.rgba(1, 1, 1, 0.8)
                                            onClicked: MprisState.cardPlayer?.next()
                                        }
                                        TrackButton {
                                            text: ""
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

                                // player switcher — glyph shows the app in control;
                                // click cycles, right-click jumps to the first playing player
                                TrackButton {
                                    id: expandedSwitcher

                                    // small and unobtrusive — brightens on hover
                                    z: 10
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    opacity: swExpHover.hovered ? 1 : 0.5
                                    text: MprisState.appGlyph(MprisState.cardPlayer)
                                    ghost: true
                                    accentColor: MprisState.pinIdentity.length > 0 ? "#f1fa8c" : Qt.rgba(1, 1, 1, 0.6)
                                    onClicked: MprisState.cycleCardPin()
                                    anchors {
                                        right: parent.right
                                        bottom: parent.bottom
                                        rightMargin: 6
                                        bottomMargin: 6
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: MprisState.jumpToPlaying()
                                    }
                                }

                                    HoverHandler {
                                        id: swExpHover
                                    }

                                // ── volume HUD — value only, scrimmed over the expanded art ──
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: Qt.rgba(0, 0, 0, 0.6)
                                    border.width: 1
                                    border.color: Qt.rgba(nowPlayingCard.volumeColor.r, nowPlayingCard.volumeColor.g, nowPlayingCard.volumeColor.b, 0.5)
                                    visible: nowPlayingCard.showVolumeBadge
                                    opacity: visible ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 140
                                            easing.type: Easing.OutQuad
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: `${nowPlayingCard.currentVolume}%`
                                        color: nowPlayingCard.volumeColor
                                        font {
                                            pixelSize: 34
                                            bold: true
                                            family: "ZedMono Nerd Font"
                                        }
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
                            implicitHeight: volumeCol.implicitHeight + 16

                            ColumnLayout {
                                id: volumeCol
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 5

                                Brightness {
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    visible: BrightnessState.available
                                    color: "#343746"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        SinkName {
                                            node: PipewireState.outputSink
                                            fallback: "output"
                                            accent: "#bd93f9"
                                            displayName: PipewireState.outputDisplayName
                                        }

                                        Rectangle {
                                            id: pwBtn

                                            // pw management shortcut (hyprpwcenter)
                                            implicitWidth: 18
                                            implicitHeight: 18
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
                                    }

                                    VolumeSlider {
                                        id: outVol
                                        node: PipewireState.outputSink
                                        glyph: "\uf028"
                                        glyphMuted: "\uf026"
                                        accent: "#bd93f9"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

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
        signal picked

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
