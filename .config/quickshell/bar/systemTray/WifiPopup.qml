import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import qs.services

Item {
    id: root

    required property var host

    property Item anchorItem

    readonly property var adapter: NetworkState.adapter
    property var passwordNetwork: null
    property bool showDetails: false

    readonly property var networks: {
        const list = [...(root.adapter?.networks.values ?? [])];
        list.sort((a, b) => ((b.connected === true) - (a.connected === true))
            || ((b.signalStrength ?? 0) - (a.signalStrength ?? 0))
            || String(a.ssid ?? "").localeCompare(String(b.ssid ?? "")));
        return list;
    }

    // WifiSecurityType order: wpa3-suiteb(0) sae(1) wpa2-eap(2) wpa2-psk(3)
    // wpa-eap(4) wpa-psk(5) static-wep(6) dynamic-wep(7) leap(8) owe(9) open(10) unknown(11)
    function secLabel(s) {
        const names = ["wpa3-suiteb", "sae", "wpa2-eap", "wpa2-psk", "wpa-eap", "wpa-psk", "static-wep", "dynamic-wep", "leap", "owe", "open", "unknown"];
        return names[s] ?? "unknown";
    }

    function needsPsk(s) {
        return s >= 0 && s <= 8;
    }

    function signalColor(level, connected) {
        if (connected === true)
            return "#50fa7b";
        const s = level ?? 0;
        return s < 0.34 ? "#ffb86c" : s < 0.67 ? "#f1fa8c" : "#8be9fd";
    }

    Connections {
        target: NetworkState

        function onWifiPopupVisibleChanged() {
            if (!NetworkState.wifiPopupVisible) {
                root.passwordNetwork = null;
                root.showDetails = false;
                NetworkState.wifiGraphEnabled = false;
            }
            if (root.adapter)
                root.adapter.scannerEnabled = NetworkState.wifiPopupVisible;
        }
    }

    component SignalBars: Row {
        id: sbars
        property real level
        property color litColor

        spacing: 2

        Repeater {
            model: 4

            Rectangle {
                required property int index
                width: 3
                height: 4 + index * 2.5
                radius: 1
                anchors.bottom: parent.bottom
                color: index < Math.round((sbars.level ?? 0) * 4) ? sbars.litColor : "#44475a"
            }
        }
    }

    LazyLoader {
        loading: true

        PopupWindow {
            id: wifiPopup
            visible: NetworkState.wifiPopupVisible
            grabFocus: true
            color: "transparent"

            anchor.window: root.host
            anchor.rect.x: {
                let globalPos = root.anchorItem ? root.anchorItem.mapToGlobal(0, 0) : { x: 0 };
                return globalPos.x + (root.anchorItem ? root.anchorItem.width / 2 : 0) - width / 2;
            }

            anchor.rect.y: 33

            implicitWidth: 300
            implicitHeight: card.implicitHeight + 28

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#282a36"
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.35)

                Shortcut {
                    sequence: "Escape"
                    onActivated: {
                        if (root.passwordNetwork)
                            root.passwordNetwork = null;
                        else
                            NetworkState.wifiPopupVisible = false;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: NetworkState.wifiPopupVisible = false
                }

                ColumnLayout {
                    id: card
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    // ── Header: status left · graph + power toggles right ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: wifiPillText.implicitWidth + 16
                            implicitHeight: 18
                            radius: 9
                            color: !root.adapter ? Qt.rgba(98 / 255, 114 / 255, 164 / 255, 0.18)
                                : NetworkState.wifiConnected ? Qt.rgba(80 / 255, 250 / 255, 123 / 255, 0.16)
                                : Networking.wifiEnabled ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.16)
                                : Qt.rgba(98 / 255, 114 / 255, 164 / 255, 0.18)

                            Text {
                                id: wifiPillText
                                anchors.centerIn: parent
                                text: !root.adapter ? "no adapter"
                                    : NetworkState.wifiConnected ? "connected"
                                    : Networking.wifiEnabled ? "idle"
                                    : "off"
                                color: !root.adapter ? "#6272a4"
                                    : NetworkState.wifiConnected ? "#50fa7b"
                                    : Networking.wifiEnabled ? "#bd93f9"
                                    : "#6272a4"
                                font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            }

                            // click the status to inspect the current connection
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: NetworkState.wifiConnected
                                onClicked: root.showDetails = !root.showDetails
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: root.adapter !== null
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 22
                            implicitHeight: 18
                            radius: 6
                            color: graphBtnMouse.containsMouse || NetworkState.wifiGraphEnabled ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.16) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf1fe"
                                color: NetworkState.wifiGraphEnabled ? "#bd93f9" : "#6272a4"
                                font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                            }

                            MouseArea {
                                id: graphBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NetworkState.wifiGraphEnabled = !NetworkState.wifiGraphEnabled
                            }
                        }

                        Rectangle {
                            visible: root.adapter !== null
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 26
                            implicitHeight: 14
                            radius: 7
                            color: Networking.wifiEnabled ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.35) : "#343746"

                            Rectangle {
                                x: Networking.wifiEnabled ? parent.width - width - 2 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: Networking.wifiEnabled ? "#bd93f9" : "#6272a4"

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#44475a"
                    }

                    // ── Current connection details (click status pill) ──
                    ColumnLayout {
                        visible: root.showDetails && NetworkState.wifiConnected
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { label: "ssid", value: NetworkState.activeNetwork?.ssid ?? "-" },
                                { label: "signal", value: Math.round((NetworkState.activeNetwork?.signalStrength ?? 0) * 100) + "%" },
                                { label: "security", value: NetworkState.activeNetwork != null ? root.secLabel(NetworkState.activeNetwork.security) : "-" },
                                { label: "device", value: root.adapter?.name ?? "-" }
                            ]

                            RowLayout {
                                required property var modelData
                                spacing: 8
                                Layout.fillWidth: true

                                Text {
                                    text: modelData.label
                                    color: "#6272a4"
                                    font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                                    Layout.preferredWidth: 56
                                }

                                Text {
                                    text: modelData.value
                                    color: "#f8f8f2"
                                    elide: Text.ElideRight
                                    font { pixelSize: 11; family: "ZedMono Nerd Font" }
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        visible: root.showDetails && NetworkState.wifiConnected
                        color: "#44475a"
                    }

                    // ── Wifi signal history graph ──
                    ColumnLayout {
                        visible: NetworkState.wifiGraphEnabled
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "signal · last 3 min"
                                color: "#6272a4"
                                font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: `${Math.round((NetworkState.activeNetwork?.signalStrength ?? 0) * 100)}%`
                                color: "#bd93f9"
                                font { pixelSize: 9; family: "ZedMono Nerd Font" }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.03)
                            clip: true

                            Canvas {
                                id: signalCanvas

                                anchors.fill: parent
                                anchors.margins: 5

                                property var samples: NetworkState.wifiSignalHistory

                                onSamplesChanged: requestPaint()
                                onWidthChanged: requestPaint()

                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    ctx.strokeStyle = "rgba(255, 255, 255, 0.07)";
                                    ctx.lineWidth = 1;
                                    for (const fy of [0.05, 0.5, 0.95]) {
                                        ctx.beginPath();
                                        ctx.moveTo(0, height * fy);
                                        ctx.lineTo(width, height * fy);
                                        ctx.stroke();
                                    }

                                    const vals = signalCanvas.samples;
                                    if (!vals || vals.length < 2)
                                        return;

                                    const stepX = width / (vals.length - 1);
                                    const yFor = v => height - (Math.min(Math.max(v, 0), 1) * (height - 5) + 2.5);

                                    const grad = ctx.createLinearGradient(0, 0, 0, height);
                                    grad.addColorStop(0, "rgba(189, 147, 249, 0.32)");
                                    grad.addColorStop(1, "rgba(189, 147, 249, 0.02)");

                                    ctx.beginPath();
                                    ctx.moveTo(0, yFor(vals[0]));
                                    for (let i = 1; i < vals.length; i++)
                                        ctx.lineTo(i * stepX, yFor(vals[i]));
                                    ctx.lineTo(width, height);
                                    ctx.lineTo(0, height);
                                    ctx.closePath();
                                    ctx.fillStyle = grad;
                                    ctx.fill();

                                    ctx.beginPath();
                                    ctx.moveTo(0, yFor(vals[0]));
                                    for (let i = 1; i < vals.length; i++)
                                        ctx.lineTo(i * stepX, yFor(vals[i]));
                                    ctx.strokeStyle = "#bd93f9";
                                    ctx.lineWidth = 1.5;
                                    ctx.lineJoin = "round";
                                    ctx.stroke();
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        visible: Networking.wifiEnabled && root.networks.length > 0
                        color: "#44475a"
                    }

                    Repeater {
                        model: Networking.wifiEnabled ? root.networks : []

                        delegate: RowLayout {
                            id: netrow

                            required property var modelData

                            readonly property bool isConnected: modelData?.connected === true
                            readonly property bool isKnown: modelData?.known === true
                            readonly property string ssidName: modelData?.ssid ?? ""
                            readonly property bool hiddenNet: ssidName.length === 0

                            spacing: 7
                            Layout.fillWidth: true
                            opacity: isConnected ? 1 : 0.85

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!netrow.modelData)
                                        return;
                                    root.passwordNetwork = null;
                                    if (netrow.isConnected) {
                                        netrow.modelData.disconnect();
                                    } else if (netrow.isKnown || !root.needsPsk(netrow.modelData.security)) {
                                        netrow.modelData.connect();
                                    } else {
                                        // secured and unknown: ask for the password first
                                        root.passwordNetwork = netrow.modelData;
                                        pwField.forceActiveFocus();
                                    }
                                }
                            }

                            SignalBars {
                                level: netrow.modelData?.signalStrength ?? 0
                                litColor: root.signalColor(netrow.modelData?.signalStrength ?? 0, netrow.isConnected)
                                Layout.alignment: Qt.AlignBottom
                            }

                            Text {
                                text: netrow.hiddenNet ? "hidden network" : netrow.ssidName
                                color: netrow.hiddenNet ? "#6272a4" : netrow.isConnected ? "#f8f8f2" : "#b8bfcb"
                                font.italic: netrow.hiddenNet
                                elide: Text.ElideRight
                                font {
                                    pixelSize: 11
                                    family: "Quicksand"
                                }
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "\uf023"
                                visible: root.needsPsk(netrow.modelData?.security ?? 11)
                                color: "#6272a4"
                                font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
                            }

                            // circular indicator for the connected network
                            Rectangle {
                                visible: netrow.isConnected
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: "transparent"
                                border.width: 2
                                border.color: "#50fa7b"

                                Rectangle {
                                    anchors.centerIn: parent
                                    implicitWidth: 3
                                    implicitHeight: 3
                                    radius: 1.5
                                    color: "#50fa7b"
                                }
                            }
                        }
                    }

                    // ── Inline password entry for secured networks ──
                    ColumnLayout {
                        visible: root.passwordNetwork !== null
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: `password for ${root.passwordNetwork?.ssid?.length > 0 ? root.passwordNetwork.ssid : "hidden network"}`
                            color: "#bd93f9"
                            elide: Text.ElideMiddle
                            font { pixelSize: 9; bold: true; family: "Quicksand" }
                            Layout.fillWidth: true
                        }

                        TextField {
                            id: pwField

                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            echoMode: TextInput.Password
                            placeholderText: "enter password…"
                            color: "#f8f8f2"
                            placeholderTextColor: "#6272a4"
                            font { pixelSize: 11; family: "Quicksand" }
                            background: Rectangle {
                                radius: 6
                                color: "#44475a"
                                border.color: pwField.activeFocus ? "#bd93f9" : "#6272a4"
                                border.width: 1
                            }
                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 0
                            bottomPadding: 0
                            verticalAlignment: Text.AlignVCenter
                            selectByMouse: true

                            Keys.onReturnPressed: root.submitPassword()
                            Keys.onEnterPressed: root.submitPassword()
                            Keys.onEscapePressed: root.passwordNetwork = null
                        }
                    }

                    Text {
                        visible: Networking.wifiEnabled && root.networks.length === 0 && root.adapter !== null
                        text: "scanning for networks…"
                        color: "#6272a4"
                        font { pixelSize: 10; family: "Quicksand"; italic: true }
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        visible: !root.adapter
                        text: "no wifi adapter found"
                        color: "#6272a4"
                        font { pixelSize: 10; family: "Quicksand"; italic: true }
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    function submitPassword() {
        if (!root.passwordNetwork)
            return;
        const target = root.passwordNetwork;
        const psk = pwField.text;
        root.passwordNetwork = null;
        pwField.text = "";
        if (psk.length > 0)
            target.connectWithPsk(psk);
        else
            target.connect();
    }
}
