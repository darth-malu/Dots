import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.customItems

BarBlock {
    id: root

    required property var host

    property bool showPopup: false

    readonly property string netState: {
        var raw = netFile.text.trim();
        return raw.length > 0 ? raw : "down";
    }

    readonly property bool isOnline: root.netState === "up"
    readonly property color netColor: root.isOnline ? "#a6e3a1" : "#585b70"

    FileView {
        id: netFile
        path: "file:///sys/class/net/enp5s0/operstate"
    }

    Process {
        id: ipProcess
        running: false
        command: ["sh", "-c", "ip -4 -o addr show enp5s0 2>/dev/null | awk '{print $4}' | head -1"]
        stdout: SplitParser {
            onRead: data => ipAddr = data
        }
    }

    property string ipAddr: ""

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ipProcess.running = true
    }

    onClicked: {
        showPopup = !showPopup;
    }

    content: Canvas {
        id: gauge

        readonly property bool online: root.isOnline

        implicitWidth: 22
        implicitHeight: 22

        onOnlineChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cx = width / 2;
            var cy = height / 2;
            var r = cx - 2;
            var lw = 3;

            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.strokeStyle = online ? "rgba(255, 255, 255, 0.06)" : "rgba(255, 255, 255, 0.03)";
            ctx.lineWidth = lw;
            ctx.stroke();

            if (online) {
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * 0.999);
                ctx.strokeStyle = root.netColor;
                ctx.lineWidth = lw;
                ctx.lineCap = "round";
                ctx.stroke();
            }

            ctx.fillStyle = root.netColor;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.font = `11px "Symbols Nerd Font Mono"`;
            ctx.fillText("", cx, cy + 0.5);
        }
    }

    PopupWindow {
        id: netPopup
        visible: root.showPopup
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

        implicitWidth: 240
        implicitHeight: netCol.implicitHeight + 24

        Rectangle {
            id: netCol
            anchors.fill: parent
            radius: 8
            color: "#1e1e2e"
            border.color: "#313244"

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 8

                Text {
                    text: root.isOnline ? "  Connected" : "  Disconnected"
                    color: root.netColor
                    font { pixelSize: 13; bold: true; family: "Quicksand" }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#313244"
                }

                Text {
                    text: "enp5s0"
                    color: "#cdd6f4"
                    font { pixelSize: 12; family: "ZedMono Nerd Font" }
                }

                Text {
                    text: root.ipAddr.length > 0 ? "  " + root.ipAddr : ""
                    visible: text.length > 0
                    color: "#a6adc8"
                    font { pixelSize: 11; family: "ZedMono Nerd Font" }
                }
            }
        }
    }
}
