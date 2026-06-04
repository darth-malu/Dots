import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.customItems
import qs.services

BarBlock {
    id: root

    required property var host

    property bool showMenu: false
    property bool airplaneOn: false
    property string ipAddr: ""

    readonly property string hostName: {
        var raw = hostFile.text.trim();
        return raw.length > 0 ? raw : "unknown";
    }

    FileView {
        id: hostFile
        path: "file:///proc/sys/kernel/hostname"
    }

    Process {
        id: airplaneCheck
        running: false
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => root.airplaneOn = data.trim() === "enabled"
        }
    }

    Process {
        id: ipCheck
        running: false
        command: ["sh", "-c", "ip -4 -o addr show 2>/dev/null | grep -v lo | awk '{print $4}' | head -1"]
        stdout: SplitParser {
            onRead: data => root.ipAddr = data
        }
    }

    Timer {
        id: syncTimer
        interval: 3000
        running: false
        onTriggered: {
            airplaneCheck.running = true;
            ipCheck.running = true;
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            airplaneCheck.running = true;
            ipCheck.running = true;
        }
    }

    onClicked: {
        showMenu = !showMenu;
    }

    content: Canvas {
        id: gauge

        implicitWidth: 22
        implicitHeight: 22

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cx = width / 2;
            var cy = height / 2;
            var r = cx - 2;
            var lw = 3;

            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.strokeStyle = "rgba(255, 255, 255, 0.06)";
            ctx.lineWidth = lw;
            ctx.stroke();

            ctx.beginPath();
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * 0.999);
            ctx.strokeStyle = "#89b4fa";
            ctx.lineWidth = lw;
            ctx.lineCap = "round";
            ctx.stroke();

            ctx.fillStyle = "#89b4fa";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.font = `11px "Symbols Nerd Font Mono"`;
            ctx.fillText("", cx, cy + 0.5);
        }
    }

    PopupWindow {
        id: menuPopup
        visible: root.showMenu
        grabFocus: true

        anchor.window: root.host
        anchor.rect.x: {
            let g = root.mapToGlobal(0, 0);
            return g.x + (root.width / 2) - (width / 2);
        }
        anchor.rect.y: {
            let g = root.mapToGlobal(0, 0);
            return g.y - implicitHeight - 4;
        }

        implicitWidth: 280
        implicitHeight: menuCol.implicitHeight + 24

        Rectangle {
            id: menuCol
            anchors.fill: parent
            radius: 10
            color: "#1e1e2e"
            border.color: "#313244"

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 10

                // ── User section ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: ""
                        color: "#89b4fa"
                        font { pixelSize: 28; family: "Symbols Nerd Font Mono" }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: root.hostName
                            color: "#cdd6f4"
                            font { pixelSize: 13; bold: true; family: "Quicksand" }
                        }
                        Text {
                            text: root.airplaneOn ? "  Airplane Mode" : "  Online"
                            color: root.airplaneOn ? "#f9e2af" : "#a6e3a1"
                            font { pixelSize: 11; family: "Quicksand" }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#313244"
                }

                // ── Volume section ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        spacing: 8
                        Text {
                            text: Pipewire.defaultAudioSink?.audio?.muted ? "" : ""
                            color: Pipewire.defaultAudioSink?.audio?.muted ? "#585b70" : "#cdd6f4"
                            font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                        }
                        Text {
                            text: "Volume"
                            color: "#cdd6f4"
                            font { pixelSize: 12; family: "Quicksand" }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Pipewire.ready
                                ? Math.floor((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                                : ""
                            color: "#a6adc8"
                            font { pixelSize: 11; family: "ZedMono Nerd Font" }
                        }
                    }

                    Slider {
                        id: volSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                        live: true
                        onMoved: {
                            if (Pipewire.defaultAudioSink?.audio)
                                Pipewire.defaultAudioSink.audio.volume = value;
                        }

                        background: Rectangle {
                            x: volSlider.leftPadding
                            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                            width: volSlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#313244"

                            Rectangle {
                                width: volSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: Pipewire.defaultAudioSink?.audio?.muted ? "#585b70" : "#89b4fa"
                            }
                        }

                        handle: Rectangle {
                            x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                            width: 14
                            height: 14
                            radius: 7
                            color: Pipewire.defaultAudioSink?.audio?.muted ? "#585b70" : "#89b4fa"
                            border.color: "#1e1e2e"
                            border.width: 2
                        }
                    }

                    Text {
                        text: "  Mute"
                        color: "#585b70"
                        font { pixelSize: 11; family: "Quicksand" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Pipewire.defaultAudioSink?.audio)
                                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#313244"
                }

                // ── Toggles section ──
                ToggleRow {
                    icon: ""
                    label: "Wi-Fi"
                    active: !root.airplaneOn
                    accent: "#a6e3a1"
                    onSwitched: newVal => {
                        root.airplaneOn = !newVal;
                        Quickshell.execDetached(["sh", "-c", "nmcli radio wifi " + (newVal ? "on" : "off")]);
                        syncTimer.restart();
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#313244"
                }

                // ── Power section ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    PowerBtn { iconText: ""; label: "Lock";     color: "#89b4fa"; cmd: "loginctl lock-session" }
                    PowerBtn { iconText: ""; label: "Power";   color: "#f38ba8"; cmd: "systemctl poweroff" }
                    PowerBtn { iconText: ""; label: "Reboot";  color: "#f9e2af"; cmd: "systemctl reboot" }
                    PowerBtn { iconText: ""; label: "Logout";  color: "#cba6f7"; cmd: "loginctl terminate-user $USER" }
                }
            }
        }
    }

    component ToggleRow: RowLayout {
        required property string icon
        required property string label
        property bool active: false
        property color accent: "#89b4fa"
        signal switched(bool newVal)

        spacing: 8

        Text {
            text: parent.icon
            color: parent.active ? parent.accent : "#585b70"
            font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
        }

        Text {
            text: parent.label
            color: "#cdd6f4"
            font { pixelSize: 12; family: "Quicksand" }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            width: 40
            height: 22
            radius: 11
            color: parent.active ? parent.accent : "#45475a"
            border.color: parent.active ? parent.accent : "#585b70"
            border.width: 1

            Rectangle {
                x: parent.active ? parent.width - width - 2 : 2
                y: 2
                width: 16
                height: 16
                radius: 8
                color: "#1e1e2e"

                Behavior on x { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.switched(!parent.parent.active)
            }
        }
    }

    component PowerBtn: ColumnLayout {
        required property string iconText
        required property string label
        required property color color
        required property string cmd

        Layout.fillWidth: true
        spacing: 4

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 8
            color: "#313244"

            Text {
                anchors.centerIn: parent
                text: parent.parent.parent.iconText
                color: parent.parent.parent.color
                font { pixelSize: 16; family: "Symbols Nerd Font Mono" }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.showMenu = false;
                    Quickshell.execDetached(["sh", "-c", parent.parent.parent.cmd]);
                }
            }
        }

        Text {
            text: parent.label
            color: "#a6adc8"
            font { pixelSize: 10; family: "Quicksand" }
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }
}
