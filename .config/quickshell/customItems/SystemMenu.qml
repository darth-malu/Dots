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

    readonly property string hostName: QuickState.hostName

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
            ctx.strokeStyle = "#bd93f9";
            ctx.lineWidth = lw;
            ctx.lineCap = "round";
            ctx.stroke();

            ctx.fillStyle = "#bd93f9";
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
        color: MiscState.popupSolidBg ? "#282a36" : "transparent"

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
            color: "#282a36"
            border.color: "#343746"

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
                        color: "#bd93f9"
                        font { pixelSize: 28; family: "Symbols Nerd Font Mono" }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: root.hostName
                            color: "#f8f8f2"
                            font { pixelSize: 13; bold: true; family: "Quicksand" }
                        }
                        Text {
                            text: root.airplaneOn ? "  Airplane Mode" : "  Online"
                            color: root.airplaneOn ? "#f1fa8c" : "#50fa7b"
                            font { pixelSize: 11; family: "Quicksand" }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#343746"
                }

                // ── Volume section ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        spacing: 8

                        Text {
                            text: Pipewire.defaultAudioSink?.audio?.muted ? "" : ""
                            color: Pipewire.defaultAudioSink?.audio?.muted ? "#6272a4" : "#f8f8f2"
                            font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                        }
                        Text {
                            text: "Volume"
                            color: "#f8f8f2"
                            font { pixelSize: 12; family: "Quicksand" }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Pipewire.ready
                                ? Math.floor((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                                : ""
                            color: "#b8bfcb"
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
                            color: "#343746"

                            Rectangle {
                                width: volSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: Pipewire.defaultAudioSink?.audio?.muted ? "#6272a4" : "#bd93f9"
                            }
                        }

                        handle: Rectangle {
                            x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                            width: 14
                            height: 14
                            radius: 7
                            color: Pipewire.defaultAudioSink?.audio?.muted ? "#6272a4" : "#bd93f9"
                            border.color: "#282a36"
                            border.width: 2
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

                    Text {
                        text: "  Mute"
                        color: "#6272a4"
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
                    color: "#343746"
                }

                // ── Toggles section ──
                ToggleRow {
                    icon: ""
                    label: "Wi-Fi"
                    active: !root.airplaneOn
                    accent: "#50fa7b"
                    onSwitched: newVal => {
                        root.airplaneOn = !newVal;
                        Quickshell.execDetached(["sh", "-c", "nmcli radio wifi " + (newVal ? "on" : "off")]);
                        syncTimer.restart();
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#343746"
                }

                // ── Power section ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    PowerBtn { iconText: ""; label: "Lock";     color: "#bd93f9"; cmd: "loginctl lock-session" }
                    PowerBtn { iconText: ""; label: "Sleep";    color: "#50fa7b"; cmd: "systemctl suspend" }
                    PowerBtn { iconText: ""; label: "Hibernate"; color: "#ff79c6"; cmd: "systemctl hibernate" }
                    PowerBtn { iconText: ""; label: "Reboot";  color: "#f1fa8c"; cmd: "systemctl reboot" }
                    PowerBtn { iconText: ""; label: "Power";   color: "#ff5555"; cmd: "systemctl poweroff" }
                    PowerBtn { iconText: ""; label: "Logout";  color: "#bd93f9"; cmd: "loginctl terminate-user $USER" }
                }
            }
        }
    }

    component ToggleRow: RowLayout {
        required property string icon
        required property string label
        property bool active: false
        property color accent: "#bd93f9"
        signal switched(bool newVal)

        spacing: 8

        Text {
            text: parent.icon
            color: parent.active ? parent.accent : "#6272a4"
            font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
        }

        Text {
            text: parent.label
            color: "#f8f8f2"
            font { pixelSize: 12; family: "Quicksand" }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            width: 40
            height: 22
            radius: 11
            color: parent.active ? parent.accent : "#44475a"
            border.color: parent.active ? parent.accent : "#6272a4"
            border.width: 1

            Rectangle {
                x: parent.active ? parent.width - width - 2 : 2
                y: 2
                width: 16
                height: 16
                radius: 8
                color: "#282a36"

                Behavior on x { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.switched(!parent.parent.active)
            }
        }
    }

    component PowerBtn: Item {
        required property string iconText
        required property string label
        required property color color
        required property string cmd

        Layout.fillWidth: true
        Layout.preferredHeight: 42

        property real scaleVal: 1

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: mouseArea.containsMouse ? Qt.rgba(parent.color.r, parent.color.g, parent.color.b, 0.12) : "transparent"
            scale: parent.scaleVal

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.iconText
                color: mouseArea.containsMouse ? parent.parent.color : Qt.rgba(parent.parent.color.r, parent.parent.color.g, parent.parent.color.b, 0.5)
                font { pixelSize: 18; family: "Symbols Nerd Font Mono" }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.label
                color: mouseArea.containsMouse ? parent.parent.color : "#6272a4"
                font { pixelSize: 10; family: "Quicksand"; bold: true }

                Behavior on color {
                    ColorAnimation { duration: 120 }
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
                root.showMenu = false;
                Quickshell.execDetached(["sh", "-c", parent.cmd]);
            }
        }

        Behavior on scaleVal {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }
}
