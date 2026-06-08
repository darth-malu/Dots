import QtQuick
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

    property string activeInterface: ""
    property string ipAddr: ""
    property string diskData: ""
    property string diskDataPending: ""

    readonly property string hostName: {
        var raw = hostFile.text().trim();
        return raw.length > 0 ? raw : "unknown";
    }

    readonly property string netState: {
        var raw = netFile.text().trim();
        return raw.length > 0 ? raw : "down";
    }

    readonly property bool isOnline: root.netState === "up"

    property bool wifiEnabled: false
    property bool bluetoothEnabled: false
    property bool ethernetConnected: false
    property bool playerListOpen: false
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
                if (data.trim().length > 0)
                    root.activeInterface = data.trim();
            }
        }
    }

    Process {
        id: ipProcess
        running: false
        command: ["sh", "-c", `ip -4 -o addr show ${root.activeInterface} 2>/dev/null | awk '{print $4}' | head -1`]
        stdout: SplitParser {
            onRead: data => ipAddr = data
        }
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
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep Powered | awk '{print $2}'"]
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
            interfaceCheck.running = true;
            if (root.activeInterface.length > 0)
                ipProcess.running = true;
            root.diskDataPending = "";
            diskProcess.running = true;
            diskSwapTimer.restart();
            wifiProcess.running = true;
            btProcess.running = true;
            ethProcess.running = true;
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

    function refreshConnections() {
        wifiProcess.running = true;
        btProcess.running = true;
        ethProcess.running = true;
    }

    onMiddleClicked: {
        qsPopup.visible = !qsPopup.visible;
        if (qsPopup.visible)
            refreshConnections();
    }
    onLeftClicked: MiscState.toggleVolume = !MiscState.toggleVolume
    onRightClicked: MiscState.toggleSysTray = !MiscState.toggleSysTray

    Shortcut {
        sequence: "Escape"
        onActivated: qsPopup.visible = false
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
        visible: false
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
        implicitHeight: qsContent.implicitHeight + 16

        Rectangle {
            anchors.fill: parent
            radius: 12
            layer.enabled: true
            layer.samples: 8
            color: "#1e1e2e"
            border.color: "#45475a"

            ColumnLayout {
                id: qsContent
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                }
                spacing: 0

                // ═══ HEADER ═══
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    color: "transparent"

                    RowLayout {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 6
                        }
                        spacing: 10

                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 8
                            color: Qt.rgba(0.78, 0.60, 0.86, 0.18)

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

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: root.hostName
                                color: "#cdd6f4"
                                font {
                                    pixelSize: 13
                                    bold: true
                                    family: "Quicksand"
                                }
                            }
                            Text {
                                text: root.ipAddr.length > 0 ? root.ipAddr : (root.isOnline ? "connected" : "offline")
                                color: root.isOnline ? "#89b4fa" : "#585b70"
                                font {
                                    pixelSize: 10
                                    family: "ZedMono Nerd Font"
                                }
                            }
                        }
                    }

                    Text {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 6
                        }
                        text: root.isOnline ? "" : ""
                        color: root.isOnline ? "#89b4fa" : "#585b70"
                        font {
                            pixelSize: 16
                            family: "Symbols Nerd Font Mono"
                        }
                    }
                }

                // ═══ CONTENT ═══
                ColumnLayout {
                    id: contentCol
                    Layout.fillWidth: true
                    spacing: 0

                    // ═══ NOW PLAYING ═══
                    Card {
                        title: "Now Playing"
                        icon: ""
                        accent: "#cba6f7"
                        visible: MprisState.player !== null

                        RowLayout {
                            spacing: 12
                            Layout.fillWidth: true

                            Rectangle {
                                implicitWidth: 80
                                implicitHeight: 80
                                radius: 14
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
                                    radius: 14
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
                                        pixelSize: 32
                                        family: "Symbols Nerd Font Mono"
                                    }
                                    visible: albumArt.status !== Image.Ready
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: MprisState.player?.trackTitle || "No track"
                                    color: "#cba6f7"
                                    font {
                                        pixelSize: 13
                                        bold: true
                                        family: "Quicksand"
                                    }
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: MprisState.player?.trackArtist || MprisState.player?.identity || ""
                                    color: "#a6adc8"
                                    font {
                                        pixelSize: 11
                                        family: "ZedMono Nerd Font"
                                    }
                                    elide: Text.ElideRight
                                }
                            }

                            RowLayout {
                                spacing: 5

                                TrackButton {
                                    text: ""
                                    bgColor: "#45475a"
                                    textColor: "#cba6f7"
                                    onClicked: MprisState.player?.previous()
                                }
                                TrackButton {
                                    text: MprisState.player?.isPlaying ? "" : ""
                                    bgColor: "#cba6f7"
                                    textColor: "#1e1e2e"
                                    onClicked: MprisState.player?.togglePlaying()
                                }
                                TrackButton {
                                    text: ""
                                    bgColor: "#45475a"
                                    textColor: "#cba6f7"
                                    onClicked: MprisState.player?.next()
                                }
                            }
                        }

                        RowLayout {
                            Layout.topMargin: 8
                            Layout.fillWidth: true
                            visible: MprisState.player?.volumeSupported ?? false
                            spacing: 6

                            Item {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 4
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: "#313244"

                                    Rectangle {
                                        width: parent.width * Math.min((MprisState.player?.volume ?? 0), 1)
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
                                        var v = Math.max(0, Math.min(mx / width, 1));
                                        if (MprisState.player) MprisState.player.volume = v;
                                    }

                                    onPressed: mouse => { dragging = true; setVolFromMouse(mouse.x); }
                                    onPositionChanged: mouse => { if (dragging) setVolFromMouse(mouse.x); }
                                    onReleased: { dragging = false; }
                                    onClicked: mouse => {
                                        if (mouse.button == Qt.RightButton) {
                                            if (!MprisState.player) return;
                                            MprisState.player.volume = MprisState.player.volume > 0 ? 0 : 0.5;
                                        } else {
                                            setVolFromMouse(mouse.x);
                                        }
                                    }
                                    onWheel: event => {
                                        if (!MprisState.player) return;
                                        var v = MprisState.player.volume;
                                        v += event.angleDelta.y > 0 ? 0.05 : -0.05;
                                        MprisState.player.volume = Math.max(0, Math.min(v, 1));
                                    }
                                }
                            }

                            Text {
                                text: Math.round((MprisState.player?.volume ?? 0) * 100) + "%"
                                color: "#585b70"
                                font { pixelSize: 9; family: "ZedMono Nerd Font" }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
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

                                        Text {
                                            text: ""
                                            color: Themes.toxicGreen
                                            font {
                                                pixelSize: 7
                                                family: "Symbols Nerd Font Mono"
                                            }
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
                                            ColorAnimation {
                                                duration: 80
                                            }
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

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Text {
                                    text: ""
                                    color: root.wifiEnabled ? "#89b4fa" : "#585b70"
                                    font {
                                        pixelSize: 14
                                        family: "Symbols Nerd Font Mono"
                                    }
                                }

                                Text {
                                    text: "Wi-Fi"
                                    color: "#cdd6f4"
                                    font {
                                        pixelSize: 11
                                        family: "Quicksand"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.wifiEnabled ? "On" : "Off"
                                    color: root.wifiEnabled ? "#a6e3a1" : "#585b70"
                                    font {
                                        pixelSize: 10
                                        family: "ZedMono Nerd Font"
                                        bold: true
                                    }
                                }

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
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(["sh", "-c", root.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on"]);
                                            root.refreshConnections();
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#313244"
                            }

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Text {
                                    text: ""
                                    color: root.bluetoothEnabled ? "#89b4fa" : "#585b70"
                                    font {
                                        pixelSize: 14
                                        family: "Symbols Nerd Font Mono"
                                    }
                                }

                                Text {
                                    text: "Bluetooth"
                                    color: "#cdd6f4"
                                    font {
                                        pixelSize: 11
                                        family: "Quicksand"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.bluetoothEnabled ? "On" : "Off"
                                    color: root.bluetoothEnabled ? "#a6e3a1" : "#585b70"
                                    font {
                                        pixelSize: 10
                                        family: "ZedMono Nerd Font"
                                        bold: true
                                    }
                                }

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
                                            Quickshell.execDetached(["sh", "-c", root.bluetoothEnabled ? "bluetoothctl power off" : "bluetoothctl power on"]);
                                            root.refreshConnections();
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#313244"
                            }

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Text {
                                    text: ""
                                    color: root.ethernetConnected ? "#a6e3a1" : "#585b70"
                                    font {
                                        pixelSize: 14
                                        family: "Symbols Nerd Font Mono"
                                    }
                                }

                                Text {
                                    text: "Ethernet"
                                    color: "#cdd6f4"
                                    font {
                                        pixelSize: 11
                                        family: "Quicksand"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.ethernetConnected ? "Connected" : "Disconnected"
                                    color: root.ethernetConnected ? "#a6e3a1" : "#585b70"
                                    font {
                                        pixelSize: 10
                                        family: "ZedMono Nerd Font"
                                        bold: true
                                    }
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
                            spacing: 6
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

                                // mute/volume icon
                                Text {
                                    text: volCol.isMuted ? "" : ""
                                    color: volCol.volColor
                                    font { pixelSize: 16; family: "Symbols Nerd Font Mono" }

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

                                // percentage
                                Text {
                                    text: Pipewire.ready
                                        ? Math.floor((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                                        : ""
                                    color: volCol.isMuted ? "#585b70" : "#cdd6f4"
                                    font { pixelSize: 13; bold: true; family: "ZedMono Nerd Font" }
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
                                    Layout.topMargin: 2

                                    Text {
                                        text: modelData.identity
                                        color: "#585b70"
                                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 60
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

                    // ═══ CAFFEINE ═══
                    Card {
                        title: "Caffeine"
                        icon: CaffeineService.enabled ? "" : "󰾪"
                        accent: CaffeineService.enabled ? "#fab387" : "#585b70"
                        cardColor: CaffeineService.enabled ? Qt.rgba(0.98, 0.70, 0.53, 0.06) : "#181825"

                        Behavior on cardColor {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true

                            Text {
                                text: CaffeineService.enabled ? "Prevent idle suspend" : "Allow idle suspend"
                                color: CaffeineService.enabled ? "#fab387" : "#a6adc8"
                                font {
                                    pixelSize: 10
                                    family: "Quicksand"
                                }
                                elide: Text.ElideRight
                                Layout.fillWidth: true

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 22
                                radius: 11
                                color: CaffeineService.enabled ? "#fab387" : "#45475a"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: "#1e1e2e"
                                    x: CaffeineService.enabled ? parent.width - width - 2 : 2
                                    y: (parent.height - height) / 2

                                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: CaffeineService.toggle()
                                }
                            }
                        }
                    }

                    // ═══ BAR ═══
                    Card {
                        title: "Bar"
                        icon: ""
                        accent: "#89b4fa"

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: ""
                                color: BarState.modernBarStyle ? "#89b4fa" : "#585b70"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                            }

                            ColumnLayout {
                                spacing: 1

                                Text {
                                    text: BarState.modernBarStyle ? "Modern Bar" : "Legacy Bar"
                                    color: "#cdd6f4"
                                    font { pixelSize: 11; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: BarState.modernBarStyle ? "Rounded · 28px" : "Flat · 24px"
                                    color: "#585b70"
                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 22
                                radius: 11
                                color: BarState.modernBarStyle ? "#89b4fa" : "#45475a"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: "#1e1e2e"
                                    x: BarState.modernBarStyle ? parent.width - width - 2 : 2
                                    y: (parent.height - height) / 2

                                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: BarState.modernBarStyle = !BarState.modernBarStyle
                                }
                            }
                        }
                    }

                    // ═══ POWER ═══
                    Card {
                        title: "Power"
                        icon: ""
                        accent: "#f38ba8"
                        Layout.bottomMargin: 0

                        RowLayout {
                            spacing: 4
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
        signal clicked

        implicitWidth: 28
        implicitHeight: 28
        radius: 6
        color: mouseArea.containsMouse ? Qt.lighter(bgColor, 1.3) : bgColor

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: parent.textColor
            font {
                pixelSize: 12
                family: "Symbols Nerd Font Mono"
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
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
                qsPopup.visible = false;
                Quickshell.execDetached(["sh", "-c", parent.parent.cmd]);
            }
        }

        Behavior on scaleVal {
            NumberAnimation {
                duration: 80
                easing.type: Easing.OutCubic
            }
        }
    }
}
