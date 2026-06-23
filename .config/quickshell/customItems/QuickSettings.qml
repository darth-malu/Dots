import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

import qs.customItems
import qs.services
import qs.themes

BarBlock {
    id: root

    required property var host

    property string diskData: ""
    property string diskDataPending: ""

    property string activeInterface: ""
    property string ipAddr: ""
    readonly property string hostName: {
        var raw = hostFile.text().trim();
        return raw.length > 0 ? raw : "unknown";
    }
    readonly property string netState: {
        var raw = netFile.text().trim();
        return raw.length > 0 ? raw : "down";
    }
    readonly property bool isOnline: root.netState === "up"
    property string avatarPath: {
        var home = Quickshell.environment.HOME || "/home/" + root.hostName;
        return home + "/.config/quickshell/assets/avatar.png";
    }

    property bool wifiEnabled: false
    property bool bluetoothEnabled: false
    property bool ethernetConnected: false
    property bool playerListOpen: false
    property bool showQsPopup: false
    property string wifiSsid: ""
    property real brightness: 0
    property real maxBrightness: 100
    property bool showWifiList: false
    property bool showPowerPopup: false
    property string wifiNetworks: ""
    property bool showBtList: false
    property string btDevices: ""
    property bool compactNowPlaying: true
    property bool shuffleOn: false
    property bool loopOn: false

    FileView {
        id: hostFile
        path: "file:///proc/sys/kernel/hostname"
    }

    FileView {
        id: netFile
        path: `file:///sys/class/net/${root.activeInterface}/operstate`
    }

    Process {
        id: interfaceCheck
        running: false
        command: ["sh", "-c", "ip -o route show default 2>/dev/null | head -1 | awk '{print $5}'"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0) {
                    root.activeInterface = data.trim();
                    ipProcess.running = true;
                }
            }
        }
    }

    Process {
        id: ipProcess
        running: false
        command: ["sh", "-c", `ip -4 -o addr show ${root.activeInterface} 2>/dev/null | awk '{print $4}' | head -1`]
        stdout: SplitParser {
            onRead: data => root.ipAddr = data
        }
    }

    FileView {
        id: avatarFileWatch
        path: "file://" + root.avatarPath
        onTextChanged: {
            avatarImg.source = "";
            avatarImg.source = "file://" + root.avatarPath;
        }
    }

    Process {
        id: avatarPickProcess
        running: false
        command: ["sh", "-c", `PATH="$HOME/.nix-profile/bin:$PATH" zenity --file-selection --title="Choose Avatar" --file-filter="Images | *.png *.jpg *.jpeg *.webp" 2>/dev/null | while read file; do mkdir -p ~/.config/quickshell/assets && cp "$file" ~/.config/quickshell/assets/avatar.png; done`]
    }

    Process {
        id: diskProcess
        running: false
        command: ["sh", "-c", "df -h -x tmpfs -x devtmpfs -x squashfs -x overlay --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2"]
        stdout: SplitParser {
            onRead: data => root.diskDataPending += data + "\n"
        }
    }

    Process {
        id: wifiProcess
        running: false
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => root.wifiEnabled = data.trim() === "enabled"
        }
    }

    Process {
        id: btProcess
        running: false
        command: ["sh", "-c", "busctl get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered 2>/dev/null | grep -q true && echo yes || echo no"]
        stdout: SplitParser {
            onRead: data => root.bluetoothEnabled = data.trim() === "yes"
        }
    }

    Process {
        id: ethProcess
        running: false
        command: ["sh", "-c", "ip -o link show 2>/dev/null | grep -E '^[0-9]+: en' | grep -q 'state UP' && echo up || echo down"]
        stdout: SplitParser {
            onRead: data => root.ethernetConnected = data.trim() === "up"
        }
    }

    Process {
        id: wifiSsidProcess
        running: false
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes' | head -1 | cut -d: -f2"]
        stdout: SplitParser {
            onRead: data => root.wifiSsid = data.trim()
        }
    }

    Process {
        id: sinkProcess
        running: false
        command: ["sh", "-c", "pactl list sinks 2>/dev/null | awk '/^[[:space:]]*Name:/{n=$2} /^[[:space:]]*Description:/{d=$0; sub(/^[[:space:]]*Description: /,\"\"); print n \"|\" $0}'"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length >= 2) {
                    root.sinkList = root.sinkList.concat([{ name: parts[0], description: parts[1] }]);
                }
            }
        }
    }

    Process {
        id: brightnessProcess
        running: false
        command: ["sh", "-c", "val=$(brightnessctl get 2>/dev/null) && max=$(brightnessctl max 2>/dev/null) && echo $((val * 100 / max))"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim());
                if (!isNaN(v)) root.brightness = v;
            }
        }
    }

    Process {
        id: wifiNetworksProcess
        running: false
        command: ["sh", "-c", "nmcli -t -f SSID,SECURITY,SIGNAL dev wifi list 2>/dev/null | head -20"]
        stdout: SplitParser {
            onRead: data => root.wifiNetworks += data + "\n"
        }
    }

    Process {
        id: btDevicesProcess
        running: false
        command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | head -20"]
        stdout: SplitParser {
            onRead: data => root.btDevices += data + "\n"
        }
    }

    function refreshSinks() {
        root.sinkList = [];
        sinkProcess.running = true;
    }

    Timer {
        id: dataTimer
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.diskDataPending = "";
            diskProcess.running = true;
            diskSwapTimer.restart();
            interfaceCheck.running = true;
            wifiProcess.running = true;
            btProcess.running = true;
            ethProcess.running = true;
            wifiSsidProcess.running = true;
            if (BatteryState.available) brightnessProcess.running = true;
            root.refreshSinks();
        }
    }

    Timer {
        id: diskSwapTimer
        interval: 250
        running: false
        repeat: false
        onTriggered: () => {
            if (root.diskDataPending.trim().length > 0)
                root.diskData = root.diskDataPending;
        }
    }

    Timer {
        id: toggleCheckTimer
        interval: 600
        running: false
        repeat: false
        onTriggered: () => {
            wifiProcess.running = true;
            btProcess.running = true;
            wifiSsidProcess.running = true;
        }
    }

    function refreshConnections() {
        wifiProcess.running = true;
        btProcess.running = true;
        ethProcess.running = true;
        wifiSsidProcess.running = true;
    }

    onMiddleClicked: {
        root.showQsPopup = !root.showQsPopup;
        if (root.showQsPopup)
            refreshConnections();
    }
    onLeftClicked: MiscState.toggleVolume = !MiscState.toggleVolume
    onRightClicked: MiscState.toggleSysTray = !MiscState.toggleSysTray

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
        color: 'transparent'

        anchor.window: root.host
        anchor.rect.x: {
            let g = root.mapToGlobal(0, 0);
            return g.x + (root.width / 2) - (width / 2);
        }
        anchor.rect.y: 33
        // anchor.rect.y: {
        //     let g = root.mapToGlobal(0, 0);
        //     return g.y + root.height + 4;
        // }

        implicitWidth: 340
        implicitHeight: Math.min(qsContent.implicitHeight + 16, Screen.desktopAvailableHeight * 0.7)

        Rectangle {
            anchors.fill: parent
            radius: 12
            layer.enabled: true
            layer.samples: 8
            color: "#1e1e2e"
            border.color: "#45475a"

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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                implicitWidth: 42
                                implicitHeight: 42
                                radius: 21
                                color: "#313244"

                                Image {
                                    id: avatarImg
                                    anchors.fill: parent
                                    source: "file://" + root.avatarPath
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "#585b70"
                                    font { pixelSize: 18; family: "Symbols Nerd Font Mono" }
                                    visible: avatarImg.status !== Image.Ready
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: avatarPickProcess.running = true
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Text {
                                    text: root.hostName
                                    color: "#cdd6f4"
                                    font { pixelSize: 13; family: "Quicksand"; bold: true }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.ipAddr.length > 0
                                        ? root.ipAddr
                                        : (root.isOnline ? "Connected" : "Offline")
                                    color: root.isOnline ? "#a6e3a1" : "#f38ba8"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 6
                                color: caffeineMouse.containsMouse ? Qt.rgba(0.98, 0.70, 0.53, 0.15) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: CaffeineService.enabled ? "" : "󰾪"
                                    color: CaffeineService.enabled ? "#fab387" : "#585b70"
                                    font { pixelSize: 16; family: "Symbols Nerd Font Mono" }
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
                                color: settingsBtnMouse.containsMouse ? Qt.rgba(0.54, 0.57, 0.96, 0.15) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "#89b4fa"
                                    font { pixelSize: 16; family: "Symbols Nerd Font Mono" }
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
                                    font { pixelSize: 16; family: "Symbols Nerd Font Mono" }
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

                            QsPower { icon: ""; color: "#89b4fa"; label: "Lock"; cmd: "loginctl lock-session" }
                            QsPower { icon: ""; color: "#a6e3a1"; label: "Sleep"; cmd: "systemctl suspend" }
                            QsPower { icon: ""; color: "#f5c2e7"; label: "Hibernate"; cmd: "systemctl hibernate" }
                            QsPower { icon: ""; color: "#f9e2af"; label: "Reboot"; cmd: "systemctl reboot" }
                            QsPower { icon: ""; color: "#f38ba8"; label: "Off"; cmd: "systemctl poweroff" }
                            QsPower { icon: ""; color: "#cba6f7"; label: "Exit"; cmd: "loginctl terminate-user $USER" }
                        }
                    }

                    // ═══ NOW PLAYING ═══
                    Rectangle {
                        id: nowPlayingCard
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        radius: 10
                        clip: true
                        visible: MprisState.player !== null
                        color: "#181825"
                        implicitHeight: npContent.implicitHeight + 16

                        property color dominantColor: "#cba6f7"
                        border {
                            width: 1
                            color: Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.25)
                        }
                        Behavior on border.color { ColorAnimation { duration: 300 } }

                        property int progressTick: 0

                        // ── Album art background (gaussian blur glass) ──
                        Image {
                            id: artGlassImg
                            anchors.fill: parent
                            source: MprisState.player?.trackArtUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: root.compactNowPlaying ? 0.7 : 1.0
                            visible: status === Image.Ready
                        }

                        MultiEffect {
                            anchors.fill: artGlassImg
                            source: artGlassImg
                            blurEnabled: true
                            blur: 0.4
                            blurMax: 24
                            saturation: 0.45
                            visible: artGlassImg.visible
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0.06, 0.04, 0.15, 0.45)
                        }

                        // ── Hidden helpers ──
                        Item {
                            visible: false; width: 0; height: 0

                            Image {
                                id: hiddenArt
                                source: MprisState.player?.trackArtUrl || ""
                                asynchronous: true
                                onStatusChanged: if (status === Image.Ready) colorSampler.requestPaint()
                            }

                            Canvas {
                                id: colorSampler
                                width: 1; height: 1
                                onPaint: {
                                    var ctx = getContext("2d");
                                    if (hiddenArt.status === Image.Ready) {
                                        try {
                                            ctx.clearRect(0, 0, 1, 1);
                                            ctx.drawImage(hiddenArt, 0, 0, 1, 1);
                                            var d = ctx.getImageData(0, 0, 1, 1).data;
                                            if (d && d.length >= 4 && d[3] > 0)
                                                nowPlayingCard.dominantColor = Qt.rgba(d[0]/255, d[1]/255, d[2]/255, 1.0);
                                        } catch(e) {}
                                    }
                                }
                            }

                            Timer {
                                interval: 1000
                                running: MprisState.player?.isPlaying ?? false
                                repeat: true
                                onTriggered: nowPlayingCard.progressTick++
                            }
                        }

                        // ── Full-height album art strip (compact) ──
                        Rectangle {
                            id: compactArt
                            visible: root.compactNowPlaying
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.height
                            color: "#313244"
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: MprisState.player?.trackArtUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: ""; color: "#585b70"
                                font { pixelSize: 20; family: "Symbols Nerd Font Mono" }
                                visible: parent.children[0].status !== Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent; color: "transparent"
                                border { width: 1; color: Qt.rgba(0.80, 0.65, 0.97, 0.3) }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onWheel: wheel => {
                                var p = MprisState.player;
                                if (p?.canControl && p?.volumeSupported)
                                    p.volume = Math.max(0, Math.min(p.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05), 1));
                            }
                        }

                        // ── Content ──
                        ColumnLayout {
                            id: npContent
                            x: root.compactNowPlaying ? compactArt.width + 4 : 8
                            y: 6
                            width: parent.width - (root.compactNowPlaying ? compactArt.width + 4 + 8 : 16)
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 12
                                spacing: 0
                                Rectangle {
                                    visible: MiscState.showPlayerChooser
                                    implicitHeight: 16; radius: height / 2
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    Layout.preferredWidth: playerPill.implicitWidth + 12

                                    RowLayout {
                                        id: playerPill
                                        anchors.fill: parent; anchors.leftMargin: 5; anchors.rightMargin: 5; spacing: 3
                                        Rectangle { implicitWidth: 4; implicitHeight: 4; radius: 2; color: MprisState.player?.isPlaying ? "#88FF00" : "#585b70" }
                                        Text {
                                            text: MprisState.player?.identity || ""
                                            color: "#cdd6f4"
                                            font { pixelSize: 8; family: "Quicksand"; bold: true }
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: playerListOpen = !playerListOpen
                                    }
                                }
                                Text {
                                    visible: MiscState.showPlayerChooser
                                    text: Mpris.players.length + " player(s)"
                                    color: "#585b70"
                                    font { pixelSize: 7; family: "ZedMono Nerd Font" }
                                }
                                Item { Layout.fillWidth: true }
                                TrackButton {
                                    text: root.compactNowPlaying ? "+" : "−"
                                    accentColor: "#585b70"
                                    onClicked: root.compactNowPlaying = !root.compactNowPlaying
                                }
                            }

                            // ── COMPACT VIEW ──
                            ColumnLayout {
                                visible: root.compactNowPlaying
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: MprisState.player?.trackTitle || "No track"
                                    color: "#cdd6f4"
                                    font { pixelSize: 11; bold: true; family: "Quicksand" }
                                    elide: Text.ElideRight; maximumLineCount: 1
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: MprisState.player?.trackArtist || ""
                                    color: "#a6adc8"
                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                    elide: Text.ElideRight; maximumLineCount: 1
                                    visible: text.length > 0
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.4)
                                }

                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: 6

                                    readonly property real ratio: {
                                        nowPlayingCard.progressTick;
                                        var p = MprisState.player;
                                        if (!p) return 0;
                                        var pos = p.position; var len = p.length;
                                        if (pos == null || len == null || len <= 0 || isNaN(pos) || isNaN(len)) return 0;
                                        return Math.min(pos / len, 1);
                                    }

                                    Rectangle {
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 2; radius: 1
                                        color: Qt.rgba(1, 1, 1, 0.08)

                                        Rectangle {
                                            width: parent.width * parent.parent.ratio
                                            height: parent.height; radius: 1
                                            color: "#cba6f7"
                                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.Linear } }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            var p = MprisState.player;
                                            if (p && p.length > 0) p.position = (mouse.x / width) * p.length;
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    Item { Layout.fillWidth: true }
                                    TrackButton {
                                            text: ""
                                            visible: MiscState.showShuffle
                                            active: MprisState.player?.shuffle ?? false
                                            accentColor: MprisState.player?.shuffle ? "#f9e2af" : "#cba6f7"
                                            onClicked: { var p = MprisState.player; if (p?.canControl && p?.shuffleSupported) p.shuffle = !p.shuffle; }
                                        }
                                        TrackButton { text: ""; accentColor: "#cba6f7"; onClicked: MprisState.player?.previous() }
                                        TrackButton { text: MprisState.player?.isPlaying ? "" : ""; accentColor: "#cba6f7"; onClicked: MprisState.player?.togglePlaying() }
                                        TrackButton { text: ""; accentColor: "#cba6f7"; onClicked: MprisState.player?.next() }
                                        TrackButton {
                                            text: ""
                                            visible: MiscState.showLoop
                                            active: MprisState.player?.loopState !== MprisLoopState.None
                                            accentColor: MprisState.player?.loopState === MprisLoopState.Track ? "#f9e2af" : MprisState.player?.loopState === MprisLoopState.Playlist ? "#89b4fa" : "#cba6f7"
                                            onClicked: {
                                                var p = MprisState.player;
                                                if (!p?.canControl || !p?.loopSupported) return;
                                                var ls = p.loopState;
                                                if (ls === MprisLoopState.None) p.loopState = MprisLoopState.Track;
                                                else if (ls === MprisLoopState.Track) p.loopState = MprisLoopState.Playlist;
                                                else p.loopState = MprisLoopState.None;
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }

                            // ── EXPANDED VIEW ──
                            ColumnLayout {
                                visible: !root.compactNowPlaying
                                Layout.fillWidth: true; spacing: 6

                                Item { Layout.fillWidth: true }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 2
                                    Layout.preferredWidth: parent.parent.width - 48

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: MprisState.player?.trackTitle || "No track"
                                        color: "#ffffff"
                                        font { pixelSize: 16; bold: true; family: "Quicksand" }
                                        elide: Text.ElideRight; maximumLineCount: 2
                                        wrapMode: Text.WordWrap
                                        style: Text.Outline
                                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: MprisState.player?.trackArtist || ""
                                        color: "#e0d8f0"
                                        font { pixelSize: 12; family: "ZedMono Nerd Font" }
                                        elide: Text.ElideRight; maximumLineCount: 2
                                        visible: text.length > 0
                                        style: Text.Outline
                                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Item {
                                    Layout.fillWidth: true; Layout.preferredHeight: 16

                                    readonly property real ratio: {
                                        nowPlayingCard.progressTick;
                                        var p = MprisState.player;
                                        if (!p) return 0;
                                        var pos = p.position; var len = p.length;
                                        if (pos == null || len == null || len <= 0 || isNaN(pos) || isNaN(len)) return 0;
                                        return Math.min(pos / len, 1);
                                    }

                                    Rectangle {
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.leftMargin: 24; anchors.rightMargin: 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 3; radius: 1.5
                                        color: Qt.rgba(1, 1, 1, 0.08)

                                        Rectangle {
                                            width: parent.width * parent.parent.ratio
                                            height: parent.height; radius: 1.5
                                            color: "#cba6f7"
                                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.Linear } }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            var p = MprisState.player;
                                            if (p && p.length > 0) p.position = (mouse.x / width) * p.length;
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 6
                                    Item { Layout.fillWidth: true }
                                    TrackButton {
                                        text: ""
                                        visible: MiscState.showShuffle
                                        active: MprisState.player?.shuffle ?? false
                                        accentColor: MprisState.player?.shuffle ? "#f9e2af" : "#cba6f7"
                                        onClicked: { var p = MprisState.player; if (p?.canControl && p?.shuffleSupported) p.shuffle = !p.shuffle; }
                                    }
                                    TrackButton { text: ""; accentColor: "#cba6f7"; onClicked: MprisState.player?.previous() }
                                    TrackButton { text: MprisState.player?.isPlaying ? "" : ""; accentColor: "#cba6f7"; onClicked: MprisState.player?.togglePlaying() }
                                    TrackButton { text: ""; accentColor: "#cba6f7"; onClicked: MprisState.player?.next() }
                                    TrackButton {
                                        text: ""
                                        visible: MiscState.showLoop
                                        active: MprisState.player?.loopState !== MprisLoopState.None
                                        accentColor: MprisState.player?.loopState === MprisLoopState.Track ? "#f9e2af" : MprisState.player?.loopState === MprisLoopState.Playlist ? "#89b4fa" : "#cba6f7"
                                        onClicked: {
                                            var p = MprisState.player;
                                            if (!p?.canControl || !p?.loopSupported) return;
                                            var ls = p.loopState;
                                            if (ls === MprisLoopState.None) p.loopState = MprisLoopState.Track;
                                            else if (ls === MprisLoopState.Track) p.loopState = MprisLoopState.Playlist;
                                            else p.loopState = MprisLoopState.None;
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }

                            // ── Player list ──
                            ColumnLayout {
                                id: playerListLayout
                                Layout.fillWidth: true
                                visible: playerListOpen
                                spacing: 2

                                Instantiator {
                                    active: playerListOpen
                                    model: Mpris.players

                                    Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 18
                                        radius: 4
                                        color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                                        Behavior on color { ColorAnimation { duration: 80 } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            spacing: 6

                                            Rectangle {
                                                implicitWidth: 5; implicitHeight: 5; radius: 2.5
                                                color: modelData.playbackState === MprisPlaybackState.Playing ? "#88FF00" : "#585b70"
                                            }

                                            Text {
                                                text: modelData.identity
                                                color: modelData.playbackState === MprisPlaybackState.Playing ? "#cdd6f4" : "#585b70"
                                                font { pixelSize: 9; family: "Quicksand"; bold: true }
                                                elide: Text.ElideRight; Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: mouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                MprisState.player = modelData;
                                                playerListOpen = false;
                                            }
                                            onWheel: wheel => {
                                                if (!modelData?.canControl || !modelData?.volumeSupported) return;
                                                var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                                modelData.volume = Math.max(0, Math.min(1, (modelData.volume || 0) + delta));
                                            }
                                        }
                                    }

                                    onObjectAdded: (index, object) => object.parent = playerListLayout
                                }
                            }
                        }
                    }

                    // ═══ DISKS ═══
                    Card {
                        id: diskPlace
                        visible: false
                        title: "Disks"
                        icon: ""
                        accent: Themes.mprisTextColor

                        ColumnLayout {
                            id: disksCol
                            spacing: 6
                            Layout.fillWidth: true

                            Repeater {
                                model: {
                                    var raw = root.diskData.trim();
                                    return raw.length > 0 ? raw.split("\n") : [];
                                }

                                RowLayout {
                                    required property string modelData
                                    spacing: 8
                                    Layout.fillWidth: true

                                    readonly property var parts: modelData.trim().split(/\s+/)
                                    readonly property int pct: parts.length >= 5 ? parseInt(parts[4]) || 0 : 0

                                    Text {
                                        Layout.preferredWidth: 130
                                        text: parent.parts[0] || ""
                                        color: "#cdd6f4"
                                        font {
                                            pixelSize: 10
                                            family: "ZedMono Nerd Font"
                                        }
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.preferredWidth: 50
                                        horizontalAlignment: Text.AlignRight
                                        text: parent.parts[1] || ""
                                        color: "#585b70"
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 8
                                        radius: 4
                                        color: "#313244"

                                        Rectangle {
                                            width: parent.width * Math.min(parent.parent.pct / 100, 1)
                                            height: parent.height
                                            radius: 4
                                            color: parent.parent.pct > 90 ? "#f38ba8" : parent.parent.pct > 70 ? "#f5c2e7" : "#89dceb"

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 36
                                        horizontalAlignment: Text.AlignRight
                                        text: `${parent.pct}%`
                                        color: parent.pct > 90 ? "#f38ba8" : "#a6adc8"
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                            bold: parent.pct > 90
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "No disks found"
                                color: "#585b70"
                                font {
                                    pixelSize: 10
                                    family: "ZedMono Nerd Font"
                                }
                                visible: root.diskData.trim().length === 0
                            }
                        }
                    }

                    // ═══ CONNECTIONS ═══
                    Card {
                        title: ""
                        icon: ""
                        accent: "#89b4fa"

                        ColumnLayout {
                            spacing: 6
                            Layout.fillWidth: true

                            // ── Combined Wi‑Fi + Bluetooth row ──
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: 8
                                color: "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    // ── Wi‑Fi section ──
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: wifiHover.containsMouse
                                                ? Qt.rgba(0.54, 0.57, 0.96, root.wifiEnabled ? 0.1 : 0.06)
                                                : Qt.rgba(0.54, 0.57, 0.96, root.wifiEnabled ? 0.05 : 0.02)
                                            border {
                                                width: 1
                                                color: root.wifiEnabled
                                                    ? (wifiHover.containsMouse ? Qt.rgba(0.54, 0.57, 0.96, 0.5) : Qt.rgba(0.54, 0.57, 0.96, 0.25))
                                                    : (wifiHover.containsMouse ? Qt.rgba(0.35, 0.35, 0.44, 0.4) : Qt.rgba(0.35, 0.35, 0.44, 0.15))
                                            }
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                            Behavior on border.color { ColorAnimation { duration: 120 } }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 0
                                            anchors.rightMargin: 0
                                            spacing: 8

                                            Text {
                                                text: ""
                                                color: root.wifiEnabled ? "#89b4fa" : "#585b70"
                                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                                Layout.preferredWidth: 18
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            ColumnLayout {
                                                spacing: 1
                                                Layout.preferredWidth: 64
                                                Text {
                                                    text: "Wi-Fi"
                                                    color: root.wifiEnabled ? "#cdd6f4" : "#6c7086"
                                                    font { pixelSize: 11; family: "Quicksand"; bold: true }
                                                }
                                                Text {
                                                    text: root.wifiEnabled
                                                        ? (root.wifiSsid.length > 0 ? "Connected" : "On")
                                                        : "Off"
                                                    color: root.wifiEnabled
                                                        ? (root.wifiSsid.length > 0 ? "#a6e3a1" : "#a6adc8")
                                                        : "#585b70"
                                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                                }
                                            }

                                            Rectangle {
                                                Layout.alignment: Qt.AlignVCenter
                                                implicitWidth: 24
                                                implicitHeight: 24
                                                radius: 6
                                                color: wifiHover.containsMouse
                                                    ? Qt.rgba(0.54, 0.57, 0.96, 0.15)
                                                    : "transparent"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.wifiEnabled ? "" : ""
                                                    color: root.wifiEnabled ? "#89b4fa" : "#585b70"
                                                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: wifiHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            property bool held: false
                                            onPressed: held = false
                                            onPressAndHold: {
                                                held = true;
                                                if (root.wifiEnabled) {
                                                    root.showWifiList = !root.showWifiList;
                                                    if (root.showWifiList) {
                                                        root.wifiNetworks = "";
                                                        wifiNetworksProcess.running = true;
                                                    }
                                                }
                                            }
                                            onClicked: {
                                                if (!held) {
                                                    root.wifiEnabled = !root.wifiEnabled;
                                                    Quickshell.execDetached(["sh", "-c", "nmcli radio wifi " + (root.wifiEnabled ? "on" : "off")]);
                                                    if (!root.wifiEnabled) root.showWifiList = false;
                                                    toggleCheckTimer.restart();
                                                }
                                            }
                                        }
                                    }

                                    // ── Bluetooth section ──
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: btHover.containsMouse
                                                ? Qt.rgba(0.54, 0.57, 0.96, root.bluetoothEnabled ? 0.1 : 0.06)
                                                : Qt.rgba(0.54, 0.57, 0.96, root.bluetoothEnabled ? 0.05 : 0.02)
                                            border {
                                                width: 1
                                                color: root.bluetoothEnabled
                                                    ? (btHover.containsMouse ? Qt.rgba(0.54, 0.57, 0.96, 0.5) : Qt.rgba(0.54, 0.57, 0.96, 0.25))
                                                    : (btHover.containsMouse ? Qt.rgba(0.35, 0.35, 0.44, 0.4) : Qt.rgba(0.35, 0.35, 0.44, 0.15))
                                            }
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                            Behavior on border.color { ColorAnimation { duration: 120 } }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 0
                                            anchors.rightMargin: 0
                                            spacing: 8

                                            Text {
                                                text: ""
                                                color: root.bluetoothEnabled ? "#89b4fa" : "#585b70"
                                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                                Layout.preferredWidth: 18
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            ColumnLayout {
                                                spacing: 1
                                                Layout.preferredWidth: 64
                                                Text {
                                                    text: "Bluetooth"
                                                    color: root.bluetoothEnabled ? "#cdd6f4" : "#6c7086"
                                                    font { pixelSize: 11; family: "Quicksand"; bold: true }
                                                }
                                                Text {
                                                    text: root.bluetoothEnabled ? "On" : "Off"
                                                    color: root.bluetoothEnabled ? "#a6adc8" : "#585b70"
                                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                                }
                                            }

                                            Rectangle {
                                                Layout.alignment: Qt.AlignVCenter
                                                implicitWidth: 24
                                                implicitHeight: 24
                                                radius: 6
                                                color: btHover.containsMouse
                                                    ? Qt.rgba(0.54, 0.57, 0.96, 0.15)
                                                    : "transparent"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.bluetoothEnabled ? "" : ""
                                                    color: root.bluetoothEnabled ? "#89b4fa" : "#585b70"
                                                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: btHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            property bool held: false
                                            onPressed: held = false
                                            onPressAndHold: {
                                                held = true;
                                                if (root.bluetoothEnabled) {
                                                    root.showBtList = !root.showBtList;
                                                    if (root.showBtList) {
                                                        root.btDevices = "";
                                                        btDevicesProcess.running = true;
                                                    }
                                                }
                                            }
                                            onClicked: {
                                                if (!held) {
                                                    root.bluetoothEnabled = !root.bluetoothEnabled;
                                                    Quickshell.execDetached(["sh", "-c", "bluetoothctl power " + (root.bluetoothEnabled ? "on" : "off")]);
                                                    toggleCheckTimer.restart();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Combined dropdown list (scrollable) ──
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(listContainer.implicitHeight, 160)
                                visible: (root.showWifiList && root.wifiEnabled) || (root.showBtList && root.bluetoothEnabled)
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                ColumnLayout {
                                    id: listContainer
                                    width: parent.width
                                    spacing: 2

                                    // ── Wi‑Fi network list ──
                                    ColumnLayout {
                                        spacing: 2
                                        visible: root.showWifiList && root.wifiEnabled

                                        Repeater {
                                            model: {
                                                var raw = root.wifiNetworks.trim();
                                                return raw.length > 0 ? raw.split("\n") : [];
                                            }

                                            Rectangle {
                                                required property string modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 28
                                                radius: 4
                                                color: netMouse.containsMouse ? Qt.rgba(0.54, 0.57, 0.96, 0.12) : "transparent"

                                                readonly property var parts: modelData.split(":")
                                                readonly property string ssid: parts[0] || ""
                                                readonly property bool hasSecurity: (parts[1] || "") !== ""
                                                readonly property int signal: parseInt(parts[2]) || 0
                                                readonly property bool isCurrent: ssid === root.wifiSsid

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 32
                                                    anchors.rightMargin: 8
                                                    spacing: 6

                                                    Text {
                                                        text: parent.parent.isCurrent ? "" : (parent.parent.hasSecurity ? "" : "")
                                                        color: parent.parent.isCurrent ? "#a6e3a1" : "#585b70"
                                                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                                    }

                                                    Text {
                                                        text: parent.parent.ssid
                                                        color: parent.parent.isCurrent ? "#a6e3a1" : "#cdd6f4"
                                                        font { pixelSize: 10; family: "ZedMono Nerd Font"; bold: parent.parent.isCurrent }
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    Rectangle {
                                                        implicitWidth: 40
                                                        implicitHeight: 6
                                                        radius: 3
                                                        color: "#313244"

                                                        Rectangle {
                                                            width: parent.width * Math.min(parent.parent.signal / 100, 1)
                                                            height: parent.height
                                                            radius: 3
                                                            color: parent.parent.signal > 70 ? "#a6e3a1" : parent.parent.signal > 40 ? "#f9e2af" : "#f38ba8"
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: netMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (parent.ssid.length > 0 && !parent.isCurrent) {
                                                            Quickshell.execDetached(["sh", "-c", "nmcli dev wifi connect '" + parent.ssid.replace(/'/g, "'\\''") + "'"]);
                                                            root.showWifiList = false;
                                                            toggleCheckTimer.restart();
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: "No networks found"
                                            color: "#585b70"
                                            font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                            visible: root.wifiNetworks.trim().length === 0
                                            Layout.leftMargin: 32
                                            Layout.topMargin: 2
                                        }
                                    }

                                    // ── Bluetooth devices list ──
                                    ColumnLayout {
                                        spacing: 2
                                        visible: root.showBtList && root.bluetoothEnabled

                                        Repeater {
                                            model: {
                                                var raw = root.btDevices.trim();
                                                return raw.length > 0 ? raw.split("\n") : [];
                                            }

                                            Rectangle {
                                                required property string modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 28
                                                radius: 4
                                                color: btDevMouse.containsMouse ? Qt.rgba(0.54, 0.57, 0.96, 0.12) : "transparent"

                                                readonly property var parts: modelData.trim().split(/\s+/)
                                                readonly property string mac: parts.length >= 2 ? parts[1] : ""
                                                readonly property string btName: parts.length >= 3 ? parts.slice(2).join(" ") : ""

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 32
                                                    anchors.rightMargin: 8
                                                    spacing: 6

                                                    Text {
                                                        text: ""
                                                        color: "#89b4fa"
                                                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                                    }

                                                    Text {
                                                        text: parent.parent.btName.length > 0 ? parent.parent.btName : parent.parent.mac
                                                        color: "#cdd6f4"
                                                        font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    Text {
                                                        text: parent.parent.mac
                                                        color: "#585b70"
                                                        font { pixelSize: 8; family: "ZedMono Nerd Font" }
                                                    }
                                                }

                                                MouseArea {
                                                    id: btDevMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        Quickshell.execDetached(["sh", "-c", "bluetoothctl connect " + parent.parent.mac]);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: "No devices found"
                                            color: "#585b70"
                                            font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                            visible: root.btDevices.trim().length === 0
                                            Layout.leftMargin: 32
                                            Layout.topMargin: 2
                                        }
                                    }
                                }
                            }

                            // ── Ethernet pill ──
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: 8
                                visible: root.ethernetConnected
                                color: ethMouse.containsMouse
                                    ? Qt.rgba(0.65, 0.89, 0.63, 0.15)
                                    : Qt.rgba(0.65, 0.89, 0.63, root.ethernetConnected ? 0.08 : 0.03)
                                border {
                                    width: 1
                                    color: root.ethernetConnected
                                        ? Qt.rgba(0.65, 0.89, 0.63, 0.35)
                                        : Qt.rgba(0.35, 0.35, 0.44, 0.2)
                                }

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: ""
                                        color: root.ethernetConnected ? "#a6e3a1" : "#585b70"
                                        font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                    }

                                    Text {
                                        text: "Ethernet"
                                        color: root.ethernetConnected ? "#cdd6f4" : "#6c7086"
                                        font { pixelSize: 11; family: "Quicksand"; bold: true }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 8; implicitHeight: 8; radius: 4
                                        color: root.ethernetConnected ? "#a6e3a1" : "#585b70"
                                    }
                                }

                                MouseArea {
                                    id: ethMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }


                    // ═══ BRIGHTNESS ═══
                    Card {
                        title: "Display"
                        icon: ""
                        accent: "#f9e2af"
                        visible: BatteryState.available

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true

                            Text {
                                text: ""
                                color: "#f9e2af"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                            }

                            Text {
                                text: Math.round(root.brightness) + "%"
                                color: "#cdd6f4"
                                font { pixelSize: 10; family: "ZedMono Nerd Font"; bold: true }
                                Layout.preferredWidth: 36
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 5

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 5
                                    radius: 2.5
                                    color: "#313244"

                                    Rectangle {
                                        width: parent.width * Math.min(root.brightness / 100, 1)
                                        height: parent.height
                                        radius: 2.5
                                        color: "#f9e2af"

                                        Behavior on width {
                                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        var pct = Math.max(0, Math.min(Math.round(mouse.x / width * 100), 100));
                                        root.brightness = pct;
                                        Quickshell.execDetached(["sh", "-c", "brightnessctl set " + pct + "%"]);
                                    }
                                }
                            }
                        }
                    }


                }
            }
        }
    }

    // ═══ COMPONENTS ═══

    component SectionHeader: RowLayout {
        required property string icon
        required property string text
        required property color color

        Layout.fillWidth: true

        Text {
            text: `${parent.icon}  ${parent.text}`
            color: parent.color
            font {
                pixelSize: 10
                bold: true
                family: "Quicksand"
                letterSpacing: 1
            }
        }
        Item {
            Layout.fillWidth: true
        }
    }

    component Separator: Rectangle {
        implicitHeight: 1
        color: "#313244"
        Layout.topMargin: 4
        Layout.bottomMargin: 4
    }

    component TrackButton: Item {
        property string text
        property color accentColor: "#cba6f7"
        property bool active: false
        signal clicked

        implicitWidth: 28
        implicitHeight: 28

        property real scaleVal: 1.0
        Behavior on scaleVal { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: mouseArea.containsMouse
                ? Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.22)
                : parent.active
                    ? Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.15)
                    : Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.06)
            scale: parent.scaleVal
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: "transparent"
            border {
                width: mouseArea.containsMouse || parent.active ? 1 : 0
                color: Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.3)
            }
            Behavior on border.width { NumberAnimation { duration: 80 } }
        }

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: mouseArea.containsMouse
                ? parent.accentColor
                : (parent.active ? parent.accentColor : Qt.rgba(1, 1, 1, 0.7))
            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: parent.scaleVal = 0.85
            onReleased: parent.scaleVal = 1.0
            onClicked: parent.clicked()
        }
    }

    component QsPower: Item {
        required property string icon
        required property color color
        required property string cmd
        property string label

        Layout.fillWidth: true
        Layout.preferredHeight: 40

        property real scaleVal: 1

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: mouseArea.containsMouse ? Qt.rgba(parent.color.r, parent.color.g, parent.color.b, 0.12) : "transparent"
            scale: parent.scaleVal

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 1

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.icon
                color: mouseArea.containsMouse ? parent.parent.color : Qt.rgba(parent.parent.color.r, parent.parent.color.g, parent.parent.color.b, 0.6)
                font {
                    pixelSize: 16
                    family: "Symbols Nerd Font Mono"
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: mouseArea.containsMouse ? parent.parent.color : "#585b70"
                font {
                    pixelSize: 8
                    family: "Quicksand"
                    bold: true
                }
                visible: parent.parent.label.length > 0
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: parent.scaleVal = 0.9
            onReleased: parent.scaleVal = 1
            onClicked: {
                root.showQsPopup = false;
                root.showPowerPopup = false;
                Quickshell.execDetached(["sh", "-c", parent.cmd]);
            }
        }

        Behavior on scaleVal {
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }
        }
    }

    component Rect: Rectangle {}

    component ConnRow: RowLayout {
        property string icon
        property string label
        property string subtitle
        property bool active: false
        property bool showToggle: true
        signal toggled

        spacing: 10
        Layout.fillWidth: true
        Layout.preferredHeight: 36

        Text {
            text: parent.icon
            color: parent.active ? "#89b4fa" : "#585b70"
            font {
                pixelSize: 14
                family: "Symbols Nerd Font Mono"
            }
        }

        ColumnLayout {
            spacing: 0

            Text {
                text: parent.parent.label
                color: "#cdd6f4"
                font {
                    pixelSize: 11
                    family: "Quicksand"
                    bold: true
                }
            }

            Text {
                text: parent.parent.subtitle
                color: parent.parent.active ? "#a6adc8" : "#585b70"
                font {
                    pixelSize: 9
                    family: "ZedMono Nerd Font"
                }
                visible: parent.parent.showToggle
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: parent.showToggle
            implicitWidth: 40
            implicitHeight: 22
            radius: 11
            color: parent.active ? "#89b4fa" : "#45475a"

            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#1e1e2e"
                x: parent.parent.active ? parent.width - width - 2 : 2
                y: (parent.height - height) / 2

                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.toggled()
            }
        }

        Text {
            visible: !parent.showToggle
            text: parent.subtitle
            color: parent.active ? "#a6e3a1" : "#585b70"
            font {
                pixelSize: 10
                family: "ZedMono Nerd Font"
                bold: true
            }
        }
    }
}
