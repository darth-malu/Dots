import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.customItems
import qs.services
import qs.themes

BarBlock {
    id: root

    required property var host

    property bool showQs: false

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

    readonly property UPowerDevice bat: UPower.displayDevice
    readonly property bool batAvailable: bat.isLaptopBattery
    readonly property real batPct: bat.percentage

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

    onClicked: {
        showQs = !showQs;
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.showQs = false
    }

    content: Rectangle {
        implicitWidth: 20
        implicitHeight: 20
        radius: 4
        color: mouseArea.containsMouse ? Qt.lighter("#7cba7c", 1.2) : "#7cba7c"

        Text {
            anchors.centerIn: parent
            text: ""
            color: "#1e1e2e"
            font {
                pixelSize: 12
                family: "Symbols Nerd Font Mono"
            }
        }
    }

    PopupWindow {
        id: qsPopup
        visible: root.showQs
        grabFocus: true

        anchor.window: root.host
        anchor.rect.x: {
            let g = root.mapToGlobal(0, 0);
            return g.x + (root.width / 2) - (width / 2);
        }
        anchor.rect.y: {
            let g = root.mapToGlobal(0, 0);
            return g.y + root.height + 4;
        }

        implicitWidth: 340
        implicitHeight: Math.min(qsContent.implicitHeight + 24, 600)

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
                }
                spacing: 0

                // ═══ HEADER ═══
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    color: Qt.rgba(0.49, 0.73, 0.44, 0.08)

                    RowLayout {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 14
                        }
                        spacing: 10

                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 6
                            color: "#7cba7c"

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: "#1e1e2e"
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
                                color: root.isOnline ? Themes.toxicGreen : "#585b70"
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
                            rightMargin: 14
                        }
                        text: root.isOnline ? "" : ""
                        color: root.isOnline ? Themes.toxicGreen : "#585b70"
                        font {
                            pixelSize: 16
                            family: "Symbols Nerd Font Mono"
                        }
                    }
                }

                Separator {
                    Layout.fillWidth: true
                }

                // ═══ SCROLLABLE CONTENT ═══
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 480)
                    contentHeight: contentCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: contentCol
                        width: parent.width
                        spacing: 0
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8

                        // ═══ NOW PLAYING ═══
                        Card {
                            title: "Now Playing"
                            icon: ""
                            accent: Themes.mprisVolumeColor
                            visible: MprisState.player !== null

                            RowLayout {
                                spacing: 10
                                Layout.fillWidth: true

                                Rectangle {
                                    implicitWidth: 44
                                    implicitHeight: 44
                                    radius: 8
                                    color: "#313244"

                                    Image {
                                        id: albumArt
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
                                        font { pixelSize: 20; family: "Symbols Nerd Font Mono" }
                                        visible: albumArt.status !== Image.Ready
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: MprisState.player?.trackTitle || "No track"
                                        color: Themes.mprisTextColor
                                        font { pixelSize: 12; bold: true; family: "Quicksand" }
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: MprisState.player?.trackArtist || MprisState.player?.identity || ""
                                        color: "#a6adc8"
                                        font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                        elide: Text.ElideRight
                                    }
                                }

                                RowLayout {
                                    spacing: 4

                                    TrackButton { text: ""; onClicked: MprisState.player?.previous() }
                                    TrackButton {
                                        text: MprisState.player?.isPlaying ? "" : ""
                                        bgColor: Themes.toxicGreen
                                        textColor: "#1e1e2e"
                                        onClicked: MprisState.player?.togglePlaying()
                                    }
                                    TrackButton { text: ""; onClicked: MprisState.player?.next() }
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 4

                                Repeater {
                                    model: Mpris.players

                                    Rectangle {
                                        required property var modelData
                                        implicitWidth: chipText.implicitWidth + 12
                                        implicitHeight: 18
                                        radius: height / 2
                                        color: modelData === MprisState.player ? Themes.mprisIndicatorColor : "#313244"

                                        Text {
                                            id: chipText
                                            anchors.centerIn: parent
                                            text: modelData.identity
                                            color: modelData === MprisState.player ? "#1e1e2e" : "#a6adc8"
                                            font { pixelSize: 11; family: "Quicksand"; bold: true }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: MprisState.player = modelData
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
                                            font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.preferredWidth: 50
                                            horizontalAlignment: Text.AlignRight
                                            text: parent.parts[1] || ""
                                            color: "#585b70"
                                            font { pixelSize: 9; family: "ZedMono Nerd Font" }
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
                                                color: parent.parent.pct > 90 ? "#f38ba8" : parent.parent.pct > 70 ? "#f9e2af" : Themes.toxicGreen

                                                Behavior on width {
                                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.preferredWidth: 36
                                            horizontalAlignment: Text.AlignRight
                                            text: `${parent.pct}%`
                                            color: parent.pct > 90 ? "#f38ba8" : "#a6adc8"
                                            font { pixelSize: 9; family: "ZedMono Nerd Font"; bold: parent.pct > 90 }
                                        }
                                    }
                                }

                                Text {
                                    text: "No disks found"
                                    color: "#585b70"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                    visible: root.diskData.trim().length === 0
                                }
                            }
                        }

                        // ═══ BATTERY ═══
                        Card {
                            title: "Battery"
                            icon: ""
                            accent: "#a6e3a1"
                            visible: root.batAvailable

                            ColumnLayout {
                                spacing: 6
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: Math.floor(root.batPct * 100) + "%"
                                        color: root.batPct < 0.2 ? "#f38ba8" : root.batPct < 0.5 ? "#f9e2af" : "#a6e3a1"
                                        font { pixelSize: 20; bold: true; family: "ZedMono Nerd Font" }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Text {
                                            text: bat.state == UPowerDeviceState.Charging ? "Charging" : "Discharging"
                                            color: bat.state == UPowerDeviceState.Charging ? "#a6e3a1" : "#cdd6f4"
                                            font { pixelSize: 11; family: "Quicksand" }
                                        }
                                        Text {
                                            text: PowerProfiles.profile == PowerProfile.Performance ? "⚡ Performance" : PowerProfiles.profile == PowerProfile.PowerSaver ? "🍀 Power Saver" : "☯ Balanced"
                                            color: "#a6adc8"
                                            font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const profiles = ['power-saver', 'performance', 'balanced'];
                                                    let idx = profiles.indexOf(PowerProfiles.profile);
                                                    let next = profiles[(idx + 1) % profiles.length];
                                                    Quickshell.execDetached(["sh", "-c", `powerprofilesctl set ${next}`]);
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: bat.state == UPowerDeviceState.Charging ? "" : ""
                                        color: bat.state == UPowerDeviceState.Charging ? "#a6e3a1" : "#cdd6f4"
                                        font { pixelSize: 20; family: "Symbols Nerd Font Mono" }
                                    }
                                }

                                ProgressBar {
                                    Layout.fillWidth: true
                                    value: root.batPct
                                    from: 0
                                    to: 1

                                    background: Rectangle {
                                        implicitHeight: 6
                                        radius: 3
                                        color: "#313244"
                                    }

                                    contentItem: Rectangle {
                                        radius: 3
                                        color: root.batPct < 0.2 ? "#f38ba8" : root.batPct < 0.5 ? "#f9e2af" : "#a6e3a1"
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                            }
                        }

                        // ═══ VOLUME ═══
                        Card {
                            title: "Volume"
                            icon: ""
                            accent: "#c6a0f6"

                            ColumnLayout {
                                spacing: 6
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: Pipewire.defaultAudioSink?.audio?.muted ? "" : ""
                                        color: Pipewire.defaultAudioSink?.audio?.muted ? "#585b70" : "#c6a0f6"
                                        font { pixelSize: 18; family: "Symbols Nerd Font Mono" }
                                    }

                                    Text {
                                        text: Pipewire.ready ? Math.floor((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%" : ""
                                        color: "#cdd6f4"
                                        font { pixelSize: 16; bold: true; family: "ZedMono Nerd Font" }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: Pipewire.defaultAudioSink?.description || ""
                                        color: "#585b70"
                                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                        elide: Text.ElideRight
                                    }
                                }

                                Slider {
                                    id: volSlider
                                    Layout.fillWidth: true
                                    from: 0; to: 1; stepSize: 0.01
                                    value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                                    live: true
                                    onValueChanged: {
                                        if (pressed && Pipewire.defaultAudioSink?.audio)
                                            Pipewire.defaultAudioSink.audio.volume = value;
                                    }

                                    background: Rectangle {
                                        x: volSlider.leftPadding
                                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                        width: volSlider.availableWidth
                                        height: 6; radius: 3
                                        color: "#313244"

                                        Rectangle {
                                            width: volSlider.visualPosition * parent.width
                                            height: parent.height; radius: 3
                                            color: Pipewire.defaultAudioSink?.audio?.muted ? "#585b70" : "#c6a0f6"
                                        }
                                    }

                                    handle: Rectangle {
                                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                        width: 16; height: 16; radius: 8
                                        color: Pipewire.defaultAudioSink?.audio?.muted ? "#585b70" : "#c6a0f6"
                                        border.color: "#1e1e2e"; border.width: 2
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    onWheel: event => {
                                        if (Pipewire.defaultAudioSink?.audio) {
                                            let vol = Pipewire.defaultAudioSink.audio.volume;
                                            vol += event.angleDelta.y > 0 ? 0.05 : -0.05;
                                            Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(vol, 1));
                                        }
                                    }
                                }
                            }
                        }

                        // ═══ CAFFEINE ═══
                        Card {
                            title: "Caffeine"
                            icon: CaffeineService.enabled ? "" : "暈"
                            accent: CaffeineService.enabled ? "#f9e2af" : "#585b70"

                            RowLayout {
                                spacing: 10
                                Layout.fillWidth: true

                                Text {
                                    text: CaffeineService.enabled ? "Prevent idle suspend" : "Allow idle suspend"
                                    color: "#a6adc8"
                                    font { pixelSize: 10; family: "Quicksand" }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 44; height: 24; radius: 12
                                    color: CaffeineService.enabled ? "#f9e2af" : "#45475a"
                                    border.color: CaffeineService.enabled ? "#f9e2af" : "#585b70"
                                    border.width: 1

                                    Rectangle {
                                        x: CaffeineService.enabled ? parent.width - width - 2 : 2
                                        y: 2; width: 18; height: 18; radius: 9
                                        color: CaffeineService.enabled ? "#1e1e2e" : "#cdd6f4"
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: CaffeineService.toggle()
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

                                QsPower { icon: ""; color: "#89b4fa"; label: "Lock"; cmd: "loginctl lock-session" }
                                QsPower { icon: ""; color: "#a6e3a1"; label: "Sleep"; cmd: "systemctl suspend" }
                                QsPower { icon: ""; color: "#f9e2af"; label: "Reboot"; cmd: "systemctl reboot" }
                                QsPower { icon: ""; color: "#f38ba8"; label: "Off"; cmd: "systemctl poweroff" }
                                QsPower { icon: ""; color: "#cba6f7"; label: "Exit"; cmd: "loginctl terminate-user $USER" }
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
            font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 1 }
        }
        Item { Layout.fillWidth: true }
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

        implicitWidth: 28; implicitHeight: 28; radius: 6
        color: mouseArea.containsMouse ? Qt.lighter(bgColor, 1.3) : bgColor

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: parent.textColor
            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
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

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.icon
                color: mouseArea.containsMouse ? parent.parent.color : Qt.rgba(parent.parent.color.r, parent.parent.color.g, parent.parent.color.b, 0.6)
                font { pixelSize: 16; family: "Symbols Nerd Font Mono" }
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.label
                color: mouseArea.containsMouse ? parent.parent.color : "#585b70"
                font { pixelSize: 8; family: "Quicksand"; bold: true }
                visible: parent.parent.label.length > 0
                Behavior on color { ColorAnimation { duration: 120 } }
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
                root.showQs = false;
                Quickshell.execDetached(["sh", "-c", parent.parent.cmd]);
            }
        }

        Behavior on scaleVal {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }
}
