import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
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
    property bool showPower: false
    property string wifiNetworks: ""

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
                                    color: root.showPower ? "#f38ba8" : "#585b70"
                                    font { pixelSize: 16; family: "Symbols Nerd Font Mono" }
                                }

                                MouseArea {
                                    id: powerBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showPower = !root.showPower
                                }
                            }
                        }
                    }

                    // ═══ NOW PLAYING ═══
                    Card {
                        id: nowPlayingCard
                        title: "Now Playing"
                        icon: ""
                        accent: "#cba6f7"
                        visible: MprisState.player !== null

                        // ── Dominant color from album art ──
                        property color dominantColor: "#181825"
                        cardColor: dominantColor

                        Behavior on cardColor {
                            ColorAnimation { duration: 300 }
                        }

                        // ── Progress bar update tick ──
                        property int progressTick: 0

                        // ── Hidden helpers (non-layout children) ──
                        Item {
                            visible: false
                            width: 0
                            height: 0

                            Image {
                                id: hiddenArt
                                source: MprisState.player?.trackArtUrl || ""
                                asynchronous: true
                                onStatusChanged: if (status === Image.Ready) colorSampler.requestPaint()
                            }

                            Canvas {
                                id: colorSampler
                                width: 1
                                height: 1
                                onPaint: {
                                    var ctx = getContext("2d");
                                    if (hiddenArt.status === Image.Ready) {
                                        try {
                                            ctx.clearRect(0, 0, 1, 1);
                                            ctx.drawImage(hiddenArt, 0, 0, 1, 1);
                                            var d = ctx.getImageData(0, 0, 1, 1).data;
                                            if (d && d.length >= 4 && d[3] > 0)
                                                nowPlayingCard.dominantColor = Qt.rgba(d[0]/255, d[1]/255, d[2]/255, 0.3);
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

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // ── Large album art ──
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 180
                                implicitHeight: 180
                                radius: 16
                                color: "#313244"

                                Image {
                                    id: albumArt
                                    anchors.fill: parent
                                    source: MprisState.player?.trackArtUrl || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 16
                                    color: "transparent"
                                    border {
                                        width: 2
                                        color: Qt.rgba(0.80, 0.65, 0.97, 0.4)
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "#585b70"
                                    font {
                                        pixelSize: 48
                                        family: "Symbols Nerd Font Mono"
                                    }
                                    visible: albumArt.status !== Image.Ready
                                }
                            }

                            // ── Track title ──
                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: MprisState.player?.trackTitle || "No track"
                                color: "#cdd6f4"
                                font {
                                    pixelSize: 14
                                    bold: true
                                    family: "Quicksand"
                                }
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // ── Artist ──
                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: MprisState.player?.trackArtist || ""
                                color: "#a6adc8"
                                font {
                                    pixelSize: 11
                                    family: "ZedMono Nerd Font"
                                }
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                visible: text.length > 0
                            }

                            // ── Progress bar + time ──
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20

                                readonly property real ratio: {
                                    nowPlayingCard.progressTick;
                                    var p = MprisState.player;
                                    if (!p) return 0;
                                    var pos = p.position;
                                    var len = p.length;
                                    if (pos == null || len == null || len <= 0 || isNaN(pos) || isNaN(len)) return 0;
                                    return Math.min(pos / len, 1);
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        nowPlayingCard.progressTick;
                                        var pos = MprisState.player?.position;
                                        if (pos == null || isNaN(pos)) return "0:00";
                                        var s = Math.max(0, Math.floor(pos / 1000000));
                                        var m = Math.floor(s / 60);
                                        var sec = s % 60;
                                        return m + ":" + (sec < 10 ? "0" : "") + sec;
                                    }
                                    color: "#a6adc8"
                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        var len = MprisState.player?.length;
                                        if (len == null || isNaN(len) || len <= 0) return "--:--";
                                        var s = Math.floor(len / 1000000);
                                        if (s <= 0) return "--:--";
                                        var m = Math.floor(s / 60);
                                        var sec = s % 60;
                                        return m + ":" + (sec < 10 ? "0" : "") + sec;
                                    }
                                    color: "#a6adc8"
                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 28
                                    anchors.rightMargin: 28
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.12)

                                    Rectangle {
                                        width: parent.width * parent.parent.ratio
                                        height: parent.height
                                        radius: 2
                                        color: "#cba6f7"

                                        Behavior on width {
                                            NumberAnimation { duration: 200; easing.type: Easing.Linear }
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
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                TrackButton {
                                    text: ""
                                    bgColor: "#45475a"
                                    textColor: "#cba6f7"
                                    onClicked: MprisState.player?.previous()
                                }
                                TrackButton {
                                    id: playPauseBtn
                                    text: MprisState.player?.isPlaying ? "" : ""
                                    bgColor: "#cba6f7"
                                    textColor: "#1e1e2e"
                                    accentColor: "#1e1e2e"
                                    implicitWidth: 38
                                    implicitHeight: 38
                                    onClicked: MprisState.player?.togglePlaying()
                                }
                                TrackButton {
                                    text: ""
                                    bgColor: "#45475a"
                                    textColor: "#cba6f7"
                                    onClicked: MprisState.player?.next()
                                }
                            }

                            // ── Player pill + list ──
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Rectangle {
                                        implicitHeight: 22
                                        implicitWidth: playerPillText.implicitWidth + 32
                                        radius: height / 2
                                        color: Qt.rgba(0.1, 0.04, 0.18, 0.5)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 8
                                            spacing: 6

                                            Rectangle {
                                                implicitWidth: 6
                                                implicitHeight: 6
                                                radius: 3
                                                color: MprisState.player?.isPlaying ? "#88FF00" : "#585b70"
                                            }

                                            Text {
                                                id: playerPillText
                                                text: MprisState.player?.identity || ""
                                                color: Themes.mprisTextColor
                                                font {
                                                    pixelSize: 11
                                                    family: "Quicksand"
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

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: Mpris.players.length + " player(s)"
                                        color: "#585b70"
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                        }
                                        visible: Mpris.players.length > 1
                                    }
                                }

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
                                            implicitHeight: 20
                                            radius: 4
                                            color: mouseArea.containsMouse ? "#313244" : "transparent"

                                            Behavior on color {
                                                ColorAnimation { duration: 80 }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                spacing: 6

                                                Rectangle {
                                                    implicitWidth: 6
                                                    implicitHeight: 6
                                                    radius: 3
                                                    color: modelData.playbackState === MprisPlaybackState.Playing ? "#88FF00" : "#585b70"
                                                }

                                                Text {
                                                    text: modelData.identity
                                                    color: modelData.playbackState === MprisPlaybackState.Playing ? "#cdd6f4" : "#585b70"
                                                    font {
                                                        pixelSize: 10
                                                        family: "Quicksand"
                                                        bold: true
                                                    }
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
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
                                            }
                                        }

                                        onObjectAdded: (index, object) => object.parent = playerListLayout
                                    }
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
                        title: "Connections"
                        icon: ""
                        accent: "#89b4fa"

                        ColumnLayout {
                            spacing: 6
                            Layout.fillWidth: true

                            // ── Wi‑Fi pill ──
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 42
                                radius: 8
                                color: wifiRowMouse.containsMouse
                                    ? Qt.rgba(0.54, 0.57, 0.96, 0.15)
                                    : Qt.rgba(0.54, 0.57, 0.96, root.wifiEnabled ? 0.08 : 0.03)
                                border {
                                    width: 1
                                    color: root.wifiEnabled
                                        ? Qt.rgba(0.54, 0.57, 0.96, 0.35)
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
                                        text: ""
                                        color: root.wifiEnabled ? "#89b4fa" : "#585b70"
                                        font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Wi-Fi"
                                            color: root.wifiEnabled ? "#cdd6f4" : "#6c7086"
                                            font { pixelSize: 11; family: "Quicksand"; bold: true }
                                        }
                                        Text {
                                            text: root.wifiEnabled
                                                ? (root.wifiSsid.length > 0 ? "Connected to " + root.wifiSsid : "On")
                                                : "Off"
                                            color: root.wifiEnabled ? (root.wifiSsid.length > 0 ? "#a6e3a1" : "#a6adc8") : "#585b70"
                                            font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        implicitWidth: 40
                                        implicitHeight: 22
                                        radius: 11
                                        color: root.wifiEnabled ? "#89b4fa" : "#45475a"

                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: "#1e1e2e"
                                            x: root.wifiEnabled ? parent.width - width - 2 : 2
                                            y: (parent.height - height) / 2

                                            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        }

                                        MouseArea {
                                            id: wifiToggleMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.wifiEnabled = !root.wifiEnabled;
                                                Quickshell.execDetached(["sh", "-c", "nmcli radio wifi " + (root.wifiEnabled ? "on" : "off")]);
                                                if (!root.wifiEnabled) root.showWifiList = false;
                                                toggleCheckTimer.restart();
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: wifiRowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.wifiEnabled) {
                                            root.showWifiList = !root.showWifiList;
                                            if (root.showWifiList) {
                                                root.wifiNetworks = "";
                                                wifiNetworksProcess.running = true;
                                            }
                                        } else {
                                            root.wifiEnabled = true;
                                            Quickshell.execDetached(["sh", "-c", "nmcli radio wifi on"]);
                                            toggleCheckTimer.restart();
                                        }
                                    }
                                }
                            }

                            // ── network list dropdown (scrollable) ──
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(netList.implicitHeight, 160)
                                visible: root.showWifiList && root.wifiEnabled
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                ColumnLayout {
                                    id: netList
                                    width: parent.width
                                    spacing: 2

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
                            }

                            // ── Bluetooth pill ──
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 42
                                radius: 8
                                color: btMouse.containsMouse
                                    ? Qt.rgba(0.54, 0.57, 0.96, 0.15)
                                    : Qt.rgba(0.54, 0.57, 0.96, root.bluetoothEnabled ? 0.08 : 0.03)
                                border {
                                    width: 1
                                    color: root.bluetoothEnabled
                                        ? Qt.rgba(0.54, 0.57, 0.96, 0.35)
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
                                        text: ""
                                        color: root.bluetoothEnabled ? "#89b4fa" : "#585b70"
                                        font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                    }

                                    ColumnLayout {
                                        spacing: 1
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

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        implicitWidth: 40
                                        implicitHeight: 22
                                        radius: 11
                                        color: root.bluetoothEnabled ? "#89b4fa" : "#45475a"

                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: "#1e1e2e"
                                            x: root.bluetoothEnabled ? parent.width - width - 2 : 2
                                            y: (parent.height - height) / 2

                                            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.bluetoothEnabled = !root.bluetoothEnabled;
                                                Quickshell.execDetached(["sh", "-c", "bluetoothctl power " + (root.bluetoothEnabled ? "on" : "off")]);
                                                toggleCheckTimer.restart();
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: btMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.bluetoothEnabled = !root.bluetoothEnabled;
                                        Quickshell.execDetached(["sh", "-c", "bluetoothctl power " + (root.bluetoothEnabled ? "on" : "off")]);
                                        toggleCheckTimer.restart();
                                    }
                                }
                            }

                            // ── Ethernet pill ──
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 42
                                radius: 8
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

                                    ColumnLayout {
                                        spacing: 1
                                        Text {
                                            text: "Ethernet"
                                            color: root.ethernetConnected ? "#cdd6f4" : "#6c7086"
                                            font { pixelSize: 11; family: "Quicksand"; bold: true }
                                        }
                                        Text {
                                            text: root.ethernetConnected ? "Connected" : "Disconnected"
                                            color: root.ethernetConnected ? "#a6e3a1" : "#585b70"
                                            font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: root.ethernetConnected ? "" : ""
                                        color: root.ethernetConnected ? "#a6e3a1" : "#585b70"
                                        font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
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

                    // ═══ VOLUME ═══
                    Card {
                        title: "Audio"
                        icon: ""
                        accent: "#c6a0f6"

                        ColumnLayout {
                            id: volCol
                            spacing: 4
                            Layout.fillWidth: true

                            property bool sinkListOpen: false

                            // ── helper: OSD-inspired volume color ──
                            readonly property color volColor: {
                                var a = Pipewire.defaultAudioSink?.audio;
                                if (!a || a.muted) return "#585b70";
                                var v = a.volume;
                                if (v > 0.8) return "#f5a0d6";
                                if (v > 0.5) return "#c6a0f6";
                                if (v > 0.2) return "#89b4fa";
                                return "#b4befe";
                            }

                            readonly property bool isMuted: Pipewire.defaultAudioSink?.audio?.muted ?? false

                            // ── row 1: icon + percentage + custom slider ──
                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Row {
                                    Layout.preferredWidth: 56
                                    Layout.maximumWidth: 56
                                    spacing: 6
                                    Layout.alignment: Qt.AlignLeft

                                    Text {
                                        text: volCol.isMuted ? "" : ""
                                        color: volCol.volColor
                                        font { pixelSize: 16; family: "Symbols Nerd Font Mono" }
                                        anchors.verticalCenter: parent.verticalCenter

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var a = Pipewire.defaultAudioSink?.audio;
                                                if (a) a.muted = !a.muted;
                                            }
                                        }
                                    }

                                    Text {
                                        text: Pipewire.ready
                                            ? Math.floor((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                                            : ""
                                        color: volCol.isMuted ? "#585b70" : "#cdd6f4"
                                        font { pixelSize: 13; bold: true; family: "ZedMono Nerd Font" }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // OSD-inspired horizontal slider
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true

                                    readonly property real normVol: Pipewire.defaultAudioSink?.audio?.volume ?? 0

                                    // track
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 5
                                        radius: 2.5
                                        color: "#313244"

                                        // fill
                                        Rectangle {
                                            width: parent.width * Math.min(parent.parent.normVol, 1)
                                            height: parent.height
                                            radius: 2.5
                                            color: volCol.volColor

                                            Behavior on width {
                                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                            }
                                        }
                                    }

                                    // interaction area
                                    MouseArea {
                                        id: volSliderArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                                        property bool dragging: false

                                        function setVolFromMouse(mx) {
                                            var v = Math.max(0, Math.min(mx / width, 1));
                                            var a = Pipewire.defaultAudioSink?.audio;
                                            if (a) a.volume = v;
                                        }

                                        onPressed: mouse => {
                                            dragging = true;
                                            setVolFromMouse(mouse.x);
                                        }
                                        onPositionChanged: mouse => {
                                            if (dragging) setVolFromMouse(mouse.x);
                                        }
                                        onReleased: { dragging = false; }
                                        onClicked: mouse => {
                                            if (mouse.button == Qt.RightButton) {
                                                var a = Pipewire.defaultAudioSink?.audio;
                                                if (a) a.muted = !a.muted;
                                            } else {
                                                setVolFromMouse(mouse.x);
                                            }
                                        }

                                        onWheel: event => {
                                            var a = Pipewire.defaultAudioSink?.audio;
                                            if (a) {
                                                var v = a.volume;
                                                v += event.angleDelta.y > 0 ? 0.05 : -0.05;
                                                a.volume = Math.max(0, Math.min(v, 1));
                                            }
                                        }
                                    }
                                }
                            }

                            // ── MPRIS per-player volume ──
                            Repeater {
                                model: {
                                    let players = [];
                                    for (let p of Mpris.players.values) {
                                        if (p.volumeSupported)
                                            players.push(p);
                                    }
                                    return players;
                                }

                                RowLayout {
                                    required property var modelData
                                    spacing: 6
                                    Layout.fillWidth: true

                                    Text {
                                        text: modelData.identity
                                        color: "#585b70"
                                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                        elide: Text.ElideRight
                                        Layout.preferredWidth: 56
                                        Layout.maximumWidth: 56
                                    }

                                    // small OSD-inspired slider
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            height: 4
                                            radius: 2
                                            color: "#313244"

                                            Rectangle {
                                                width: parent.width * Math.min(modelData.volume, 1)
                                                height: parent.height
                                                radius: 2
                                                color: "#cba6f7"

                                                Behavior on width {
                                                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                                            property bool dragging: false

                                            function setVolFromMouse(mx) {
                                                modelData.volume = Math.max(0, Math.min(mx / width, 1));
                                            }

                                            onPressed: mouse => {
                                                dragging = true;
                                                setVolFromMouse(mouse.x);
                                            }
                                            onPositionChanged: mouse => {
                                                if (dragging) setVolFromMouse(mouse.x);
                                            }
                                            onReleased: { dragging = false; }
                                            onClicked: mouse => {
                                                if (mouse.button == Qt.RightButton) {
                                                    modelData.volume = modelData.volume > 0 ? 0 : 0.5;
                                                } else {
                                                    setVolFromMouse(mouse.x);
                                                }
                                            }

                                            onWheel: event => {
                                                var v = modelData.volume;
                                                v += event.angleDelta.y > 0 ? 0.05 : -0.05;
                                                modelData.volume = Math.max(0, Math.min(v, 1));
                                            }
                                        }
                                    }
                                }
                            }

                            // ── separator ──
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#313244"
                                Layout.topMargin: 2
                            }

                            // ── row: sink switcher at bottom ──
                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    id: sinkPill
                                    implicitHeight: 22
                                    implicitWidth: Math.min(sinkPillText.implicitWidth + 28, 180)
                                    Layout.maximumWidth: 180
                                    radius: height / 2
                                    color: Qt.rgba(0.1, 0.04, 0.18, 0.5)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 6
                                        spacing: 4

                                        Text {
                                            id: sinkPillText
                                            text: {
                                                var d = Pipewire.defaultAudioSink?.description;
                                                if (!d) return "No sink";
                                                var parts = d.split(".");
                                                return parts[parts.length - 1] || d;
                                            }
                                            color: "#c6a0f6"
                                            font { pixelSize: 10; family: "Quicksand"; bold: true }
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: ""
                                            color: "#c6a0f6"
                                            font { pixelSize: 7; family: "Symbols Nerd Font Mono" }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            volCol.sinkListOpen = !volCol.sinkListOpen;
                                            if (volCol.sinkListOpen)
                                                root.refreshSinks();
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // ── sink dropdown ──
                            ColumnLayout {
                                id: sinkDropdownLayout
                                Layout.fillWidth: true
                                visible: volCol.sinkListOpen
                                spacing: 2

                                Repeater {
                                    model: root.sinkList

                                    Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 22
                                        radius: 4
                                        color: sinkMA.containsMouse ? "#313244" : "transparent"

                                        Behavior on color {
                                            ColorAnimation { duration: 80 }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            spacing: 6

                                            Text {
                                                text: "●"
                                                color: modelData.name === Pipewire.defaultAudioSink?.name ? "#c6a0f6" : "transparent"
                                                font { pixelSize: 8 }
                                            }

                                            Text {
                                                text: modelData.description || modelData.name
                                                color: modelData.name === Pipewire.defaultAudioSink?.name ? "#cdd6f4" : "#585b70"
                                                font { pixelSize: 10; family: "Quicksand"; bold: true }
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: sinkMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.name !== Pipewire.defaultAudioSink?.name) {
                                                    Quickshell.execDetached(["sh", "-c",
                                                        "pactl set-default-sink \"" + modelData.name + "\""
                                                    ]);
                                                }
                                                volCol.sinkListOpen = false;
                                            }
                                        }
                                    }
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

                    // ═══ POWER ═══
                    Card {
                        title: "Power"
                        icon: ""
                        accent: "#f38ba8"
                        visible: root.showPower
                        Layout.bottomMargin: 0

                        RowLayout {
                            spacing: 3
                            Layout.fillWidth: true

                            QsPower {
                                icon: ""
                                color: "#89b4fa"
                                label: "Lock"
                                cmd: "loginctl lock-session"
                            }
                            QsPower {
                                icon: ""
                                color: "#a6e3a1"
                                label: "Sleep"
                                cmd: "systemctl suspend"
                            }
                            QsPower {
                                icon: ""
                                color: "#f5c2e7"
                                label: "Hibernate"
                                cmd: "systemctl hibernate"
                            }
                            QsPower {
                                icon: ""
                                color: "#f9e2af"
                                label: "Reboot"
                                cmd: "systemctl reboot"
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

    component TrackButton: Rectangle {
        property string text
        property color bgColor: "#313244"
        property color textColor: "#cdd6f4"
        property color accentColor: "#cba6f7"
        signal clicked

        implicitWidth: 32
        implicitHeight: 32
        radius: 8
        color: mouseArea.containsMouse ? Qt.rgba(0.80, 0.65, 0.97, 0.15) : bgColor
        border {
            width: mouseArea.containsMouse ? 1 : 0
            color: Qt.rgba(0.80, 0.65, 0.97, 0.4)
        }
        scale: pressScale

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.width { NumberAnimation { duration: 80 } }

        property real pressScale: 1.0
        Behavior on pressScale {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: mouseArea.containsMouse ? parent.accentColor : parent.textColor
            font {
                pixelSize: 14
                family: "Symbols Nerd Font Mono"
            }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: parent.pressScale = 0.85
            onReleased: parent.pressScale = 1.0
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
                anchors.horizontalCenter: parent.horizontalCenter
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
                anchors.horizontalCenter: parent.horizontalCenter
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
