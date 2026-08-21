import QtQuick
import qs.services
import qs.customItems
import Quickshell
import Quickshell.Io
import QtQuick.Layouts

Loader {
    id: loaderBig

    required property var host

    Layout.alignment: Qt.AlignVCenter
    active: NetworkState.netspeedVisible || NetworkState.netPopupVisible
    visible: NetworkState.netspeedVisible

    sourceComponent: BarBlock {
        id: root

        color: 'transparent'

        property int refreshInterval: 1000
        property string iface

        property real rxRate
        property real txRate
        property real rxPrev: 0
        property real txPrev: 0
        property real peakRx: 1
        property real peakTx: 1

        property string ipAddr: ""

        readonly property bool wifiUp: Network.wifiConnected
        readonly property bool ethUp: Network.ethernet?.hasLink ?? false
        readonly property bool online: wifiUp || ethUp
        readonly property string ssid: Network.activeNetwork?.ssid ?? ""
        readonly property real signalStrength: Network.activeNetwork?.signalStrength ?? 0

        function fmtRate(v) {
            if (v <= 0)
                return "0.0";
            if (v >= 1000)
                return (v / 1000).toFixed(2);
            if (v < 10)
                return v.toFixed(2);
            if (v < 100)
                return v.toFixed(1);
            return Math.round(v).toString();
        }

        Process {
            id: defaultInterface
            command: ["ip", "route"]
            running: false

            stdout: SplitParser {
                onRead: data => {
                    if (data.startsWith("default via")) {
                        let line = data.split(/\s/);
                        let devIndex = line.indexOf("dev");
                        if (devIndex !== -1)
                            root.iface = line[devIndex + 1];
                    }
                }
            }
        }

        Process {
            id: getRxTxBytes
            command: ["cat", "/proc/net/dev"]
            running: false

            stdout: SplitParser {
                onRead: data => {
                    data = data.trim();
                    if (data.startsWith(root.iface + ":")) {
                        const parts = data.split(/\s+/);

                        let rx = parseInt(parts[1]);
                        let tx = parseInt(parts[9]);

                        if (root.rxPrev > 0) {
                            root.rxRate = ((rx - root.rxPrev) * 8) / 1000000;
                            root.txRate = ((tx - root.txPrev) * 8) / 1000000;
                            root.peakRx = Math.max(root.peakRx * 0.995, root.rxRate, 1);
                            root.peakTx = Math.max(root.peakTx * 0.995, root.txRate, 1);
                        }

                        root.rxPrev = rx;
                        root.txPrev = tx;
                    }
                }
            }
        }

        Process {
            id: addrProc
            command: ["sh", "-c", "ip -4 -o addr show scope global"]
            running: false

            stdout: SplitParser {
                onRead: data => {
                    const parts = data.trim().split(/\s+/);
                    if (parts[1] === root.iface)
                        root.ipAddr = parts[3].split("/")[0];
                }
            }
        }

        onIfaceChanged: {
            ipAddr = "";
            addrProc.running = true;
        }

        Timer {
            interval: root.refreshInterval
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: () => {
                defaultInterface.running = true;
                getRxTxBytes.running = true;
            }
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                NetworkState.netPopupVisible = !NetworkState.netPopupVisible;
        }

        content: RowLayout {
            spacing: 6

            RowLayout {
                spacing: 4
                Text {
                    text: "\uf063"
                    color: "#89b4fa"
                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                }
                BarText {
                    text: root.rxRate === 0 ? "-" : root.fmtRate(root.rxRate)
                    color: "#89b4fa"
                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                }
            }

            Rectangle {
                implicitWidth: 1; implicitHeight: 10
                color: "#45475a"
            }

            RowLayout {
                spacing: 4
                Text {
                    text: "\uf062"
                    color: "#f5a0d6"
                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                }
                BarText {
                    text: root.txRate === 0 ? "-" : root.fmtRate(root.txRate)
                    color: "#f5a0d6"
                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                }
            }
        }

        component InfoRow: RowLayout {
            id: irow
            property string label
            property string value
            property color valueColor: "#cdd6f4"

            spacing: 8
            Layout.fillWidth: true

            Text {
                text: irow.label
                color: "#6c7086"
                font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                Layout.preferredWidth: 56
            }

            Text {
                text: irow.value
                color: irow.valueColor
                elide: Text.ElideRight
                font { pixelSize: 11; family: "ZedMono Nerd Font" }
                Layout.fillWidth: true
            }
        }

        component SpeedBar: ColumnLayout {
            id: sbar
            property string label
            property string glyph
            property color accent
            property real rate
            property real peak

            spacing: 4
            Layout.fillWidth: true

            RowLayout {
                spacing: 6
                Layout.fillWidth: true

                Text {
                    text: sbar.glyph
                    color: sbar.accent
                    font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                }

                Text {
                    text: sbar.label
                    color: "#a6adc8"
                    font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.fmtRate(sbar.rate)
                    color: sbar.accent
                    font { pixelSize: 12; bold: true; family: "ZedMono Nerd Font" }
                }

                Text {
                    text: sbar.rate >= 1000 ? "Gbps" : "Mbps"
                    color: "#6c7086"
                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: "#313244"

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 2
                    width: parent.width * Math.min(1, sbar.rate / Math.max(sbar.peak, sbar.rate))

                    Behavior on width {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }

        LazyLoader {
            loading: NetworkState.netPopupVisible

            PopupWindow {
                id: netPopup
                visible: NetworkState.netPopupVisible
                grabFocus: true
                color: "transparent"

                anchor.window: loaderBig.host
                anchor.rect.x: {
                    let globalPos = root.mapToGlobal(0, 0);
                    return globalPos.x + (root.width / 2) - (width / 2);
                }

                anchor.rect.y: 33

                implicitWidth: 256
                implicitHeight: card.implicitHeight + 28

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    radius: 12
                    color: "#1e1e2e"
                    border.width: 1
                    border.color: Qt.rgba(0.80, 0.65, 0.97, 0.3)

                    Shortcut {
                        sequence: "Escape"
                        onActivated: NetworkState.netPopupVisible = false
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: NetworkState.netPopupVisible = false
                    }

                    ColumnLayout {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "\uf1eb"
                                color: "#89b4fa"
                                font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                            }

                            Text {
                                text: "Network"
                                color: "#cdd6f4"
                                font { pixelSize: 12; bold: true; family: "Quicksand" }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: pillText.implicitWidth + 16
                                implicitHeight: 18
                                radius: 9
                                color: root.online ? Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.14) : Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.14)

                                Text {
                                    id: pillText
                                    anchors.centerIn: parent
                                    text: root.online ? "connected" : "offline"
                                    color: root.online ? "#a6e3a1" : "#f38ba8"
                                    font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: "#313244"
                        }

                        InfoRow {
                            label: "iface"
                            value: root.iface.length > 0 ? root.iface : "-"
                        }

                        InfoRow {
                            label: "ipv4"
                            value: root.ipAddr.length > 0 ? root.ipAddr : "unavailable"
                            valueColor: root.ipAddr.length > 0 ? "#cdd6f4" : "#585b70"
                        }

                        InfoRow {
                            visible: Network.adapter !== null
                            label: "wifi"
                            value: root.ssid.length > 0 ? root.ssid : (Network.wifiEnabled ? "not associated" : "disabled")
                            valueColor: root.wifiUp ? "#cdd6f4" : "#585b70"
                        }

                        RowLayout {
                            visible: root.wifiUp
                            spacing: 8
                            Layout.fillWidth: true

                            Item { Layout.preferredWidth: 56 }

                            Item { Layout.fillWidth: true }

                            Row {
                                spacing: 2
                                Repeater {
                                    model: 4

                                    Rectangle {
                                        required property int index
                                        width: 3
                                        height: 4 + index * 2.5
                                        radius: 1
                                        anchors.bottom: parent.bottom
                                        color: index < Math.round(root.signalStrength * 4) ? Network.wifiColor : "#45475a"
                                    }
                                }
                            }

                            Text {
                                text: Math.round(root.signalStrength * 100) + "%"
                                color: "#a6adc8"
                                font { pixelSize: 9; family: "ZedMono Nerd Font" }
                            }
                        }

                        InfoRow {
                            visible: Network.ethernet !== null
                            label: "eth"
                            value: root.ethUp ? "linked" : "no link"
                            valueColor: root.ethUp ? "#94e2d5" : "#585b70"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: "#313244"
                        }

                        SpeedBar {
                            label: "download"
                            glyph: "\uf063"
                            accent: "#89b4fa"
                            rate: root.online ? root.rxRate : 0
                            peak: root.peakRx
                        }

                        SpeedBar {
                            label: "upload"
                            glyph: "\uf062"
                            accent: "#f5a0d6"
                            rate: root.online ? root.txRate : 0
                            peak: root.peakTx
                        }
                    }
                }
            }
        }
    }
}
