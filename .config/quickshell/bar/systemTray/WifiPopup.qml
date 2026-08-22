import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.services

Item {
    id: root

    required property var host

    property Item anchorItem

    readonly property var adapter: NetworkState.adapter
    property var passwordNetwork: null
    property bool showDetails: false

    // BarBlock hosting this popup — provides live rx/tx histories, peaks and formatters
    property var netRoot: null

    // network settings editor (known networks)
    property string editSsid: ""
    property var autoconnMap: ({})

    readonly property var knownNets: root.networks.filter(n => n?.known === true)
    readonly property var unknownNets: root.networks.filter(n => n?.known !== true)

    readonly property var networks: {
        const list = [...(root.adapter?.networks.values ?? [])];
        list.sort((a, b) => ((b.connected === true) - (a.connected === true))
            || ((b.signalStrength ?? 0) - (a.signalStrength ?? 0))
            || String(a.name ?? "").localeCompare(String(b.name ?? "")));
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
                root.editSsid = "";
                NetworkState.wifiGraphEnabled = false;
            } else {
                connListProc.running = true;
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

    component TrafficGraph: Rectangle {
        id: tgraph

        property var history
        property real peak: 1
        property color accent: "#bd93f9"
        property int tick
        property int maxLen: 60

        Layout.fillWidth: true
        implicitHeight: 34
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.03)
        clip: true

        onTickChanged: tcanvas.requestPaint()
        onWidthChanged: tcanvas.requestPaint()

        Canvas {
            id: tcanvas

            anchors.fill: parent
            anchors.margins: 4
            antialiasing: true
            renderStrategy: Canvas.Immediate

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.strokeStyle = "rgba(255, 255, 255, 0.06)";
                ctx.lineWidth = 1;
                for (let i = 1; i <= 2; i++) {
                    ctx.beginPath();
                    ctx.moveTo(0, Math.round(height * i / 3));
                    ctx.lineTo(width, Math.round(height * i / 3));
                    ctx.stroke();
                }

                const h = tgraph.history ?? [];
                if (h.length < 2)
                    return;

                const stepX = width / (Math.max(tgraph.maxLen, 2) - 1);
                const scale = Math.max(tgraph.peak, 0.001);
                const yAt = i => height - Math.min(1, h[i] / scale) * (height - 2) - 1;

                const grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, Qt.rgba(tgraph.accent.r, tgraph.accent.g, tgraph.accent.b, 0.32));
                grad.addColorStop(1, Qt.rgba(tgraph.accent.r, tgraph.accent.g, tgraph.accent.b, 0.02));

                ctx.beginPath();
                ctx.moveTo(0, height);
                for (let i = 0; i < h.length; i++)
                    ctx.lineTo(i * stepX, yAt(i));
                ctx.lineTo((h.length - 1) * stepX, height);
                ctx.closePath();
                ctx.fillStyle = grad;
                ctx.fill();

                ctx.beginPath();
                for (let i = 0; i < h.length; i++) {
                    if (i === 0)
                        ctx.moveTo(0, yAt(i));
                    else
                        ctx.lineTo(i * stepX, yAt(i));
                }
                ctx.strokeStyle = tgraph.accent;
                ctx.lineWidth = 1.5;
                ctx.stroke();
            }
        }
    }

    component NetRow: ColumnLayout {
        id: netrow

        required property var modelData

        readonly property bool isConnected: modelData?.connected === true
        readonly property bool isKnown: modelData?.known === true
        readonly property string ssidName: modelData?.name ?? ""
        readonly property bool hiddenNet: ssidName.length === 0
        readonly property bool editing: root.editSsid.length > 0 && root.editSsid === ssidName
        property bool showPw: false

        spacing: 4
        Layout.fillWidth: true
        opacity: isConnected ? 1 : 0.85

        RowLayout {
            spacing: 7
            Layout.fillWidth: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!netrow.modelData)
                        return;
                    root.passwordNetwork = null;
                    root.editSsid = "";
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

            // connected dot, then padlock for secured networks
            Rectangle {
                visible: netrow.isConnected
                implicitWidth: 5
                implicitHeight: 5
                radius: 2.5
                color: "#50fa7b"
            }

            Text {
                text: "\uf023"
                visible: root.needsPsk(netrow.modelData?.security ?? 11)
                color: "#6272a4"
                font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
            }

            // settings editor toggle for known networks
            Text {
                visible: netrow.isKnown && netrow.ssidName.length > 0
                text: "\uf044"
                color: editMa.containsMouse || netrow.editing ? "#bd93f9" : "#6272a4"
                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }

                MouseArea {
                    id: editMa
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.passwordNetwork = null;
                        root.editSsid = netrow.editing ? "" : netrow.ssidName;
                    }
                }
            }
        }

        // ── Inline settings editor (autoconnect · password · forget) ──
        Rectangle {
            visible: netrow.editing
            Layout.fillWidth: true
            implicitHeight: editorCol.implicitHeight + 16
            radius: 8
            color: "#343746"

            ColumnLayout {
                id: editorCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "autoconnect"
                        color: "#6272a4"
                        font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        readonly property bool on: root.autoconnMap[netrow.ssidName] !== false
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 26
                        implicitHeight: 14
                        radius: 7
                        color: on ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.35) : "#44475a"

                        Rectangle {
                            x: parent.on ? parent.width - width - 2 : 2
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 10
                            implicitHeight: 10
                            radius: 5
                            color: parent.on ? "#bd93f9" : "#6272a4"

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
                            onClicked: root.setAutoconnect(netrow.ssidName, !parent.on)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    TextField {
                        id: pskEdit

                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        echoMode: netrow.showPw ? TextInput.Normal : TextInput.Password
                        placeholderText: "change password…"
                        color: "#f8f8f2"
                        placeholderTextColor: "#6272a4"
                        font { pixelSize: 10; family: "Quicksand" }
                        background: Rectangle {
                            radius: 6
                            color: "#282a36"
                            border.color: pskEdit.activeFocus ? "#bd93f9" : "#6272a4"
                            border.width: 1
                        }
                        leftPadding: 8
                        rightPadding: 8
                        topPadding: 0
                        bottomPadding: 0
                        verticalAlignment: Text.AlignVCenter
                        selectByMouse: true

                        Keys.onReturnPressed: applyBtn.applyClicked()
                        Keys.onEnterPressed: applyBtn.applyClicked()
                    }

                    // reveal / hide the typed password
                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 6
                        color: eyeMa.containsMouse ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.16) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: netrow.showPw ? "\uf070" : "\uf06e"
                            color: netrow.showPw ? "#bd93f9" : "#6272a4"
                            font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                        }

                        MouseArea {
                            id: eyeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: netrow.showPw = !netrow.showPw
                        }
                    }

                    Rectangle {
                        id: applyBtn

                        function applyClicked() {
                            if (root.changePsk(netrow.ssidName, pskEdit.text))
                                pskEdit.text = "";
                        }

                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 6
                        color: applyMa.containsMouse ? Qt.rgba(80 / 255, 250 / 255, 123 / 255, 0.16) : "#282a36"

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00c"
                            color: "#50fa7b"
                            font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                        }

                        MouseArea {
                            id: applyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: applyBtn.applyClicked()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 20
                    radius: 6
                    color: forgetMa.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.18) : "#282a36"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "\uf1f8"
                            color: "#ff5555"
                            font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                        }

                        Text {
                            text: "forget network"
                            color: "#ff5555"
                            font { pixelSize: 9; bold: true; family: "Quicksand" }
                        }
                    }

                    MouseArea {
                        id: forgetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.forgetNetwork(netrow.modelData)
                    }
                }
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
                        else if (root.editSsid.length > 0)
                            root.editSsid = "";
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

                        // status text (no background) — click to inspect the current connection
                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: wifiPillText.implicitWidth
                            implicitHeight: wifiPillText.implicitHeight

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

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
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
                                { label: "ssid", value: NetworkState.activeNetwork?.name ?? "-" },
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

                    // ── Upload/download traffic graphs + totals ──
                    ColumnLayout {
                        visible: NetworkState.wifiGraphEnabled && root.netRoot !== null
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "traffic · live"
                                color: "#6272a4"
                                font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: `↓ ${root.netRoot.fmtRate(root.netRoot.rxRate)}`
                                color: "#bd93f9"
                                font { pixelSize: 9; bold: true; family: "ZedMono Nerd Font" }
                            }

                            Text {
                                text: `↑ ${root.netRoot.fmtRate(root.netRoot.txRate)}`
                                color: "#ff79c6"
                                font { pixelSize: 9; bold: true; family: "ZedMono Nerd Font" }
                            }
                        }

                        TrafficGraph {
                            accent: "#bd93f9"
                            history: root.netRoot.rxHistory
                            peak: root.netRoot.peakRx
                            tick: root.netRoot.graphTick
                            maxLen: root.netRoot.historyMax
                        }

                        TrafficGraph {
                            accent: "#ff79c6"
                            history: root.netRoot.txHistory
                            peak: root.netRoot.peakTx
                            tick: root.netRoot.graphTick
                            maxLen: root.netRoot.historyMax
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: `total ↓ ${root.netRoot.fmtBytes(root.netRoot.ifaceRxTotal)} · ↑ ${root.netRoot.fmtBytes(root.netRoot.ifaceTxTotal)}`
                            color: "#6272a4"
                            font { pixelSize: 9; family: "ZedMono Nerd Font" }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        visible: Networking.wifiEnabled && root.networks.length > 0
                        color: "#44475a"
                    }

                    // ── Known networks ──
                    Text {
                        visible: Networking.wifiEnabled && root.knownNets.length > 0
                        text: `known · ${root.knownNets.length}`
                        color: "#6272a4"
                        font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                    }

                    Repeater {
                        model: Networking.wifiEnabled ? root.knownNets : []
                        delegate: NetRow {}
                    }

                    // ── Available (unknown) networks ──
                    Text {
                        visible: Networking.wifiEnabled && root.unknownNets.length > 0
                        text: `available · ${root.unknownNets.length}`
                        color: "#6272a4"
                        font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                    }

                    Repeater {
                        model: Networking.wifiEnabled ? root.unknownNets : []
                        delegate: NetRow {}
                    }

                    // ── Inline password entry for secured networks ──
                    ColumnLayout {
                        visible: root.passwordNetwork !== null
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: `password for ${root.passwordNetwork?.name?.length > 0 ? root.passwordNetwork.name : "hidden network"}`
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

    // ssid -> autoconnect map from NetworkManager
    Process {
        id: connListProc
        command: ["sh", "-c", "nmcli -t -f NAME,AUTOCONNECT connection show"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const i = data.lastIndexOf(":");
                if (i <= 0)
                    return;
                const m = Object.assign({}, root.autoconnMap);
                m[data.slice(0, i)] = data.slice(i + 1).trim().toLowerCase() === "yes";
                root.autoconnMap = m;
            }
        }
    }

    function esc(s) {
        return String(s).replace(/'/g, "'\\''");
    }

    function setAutoconnect(ssid, on) {
        const m = Object.assign({}, root.autoconnMap);
        m[ssid] = on;
        root.autoconnMap = m;
        if (ssid.length > 0)
            Quickshell.execDetached(["sh", "-c", `nmcli connection modify '${root.esc(ssid)}' connection.autoconnect ${on ? "yes" : "no"}`]);
    }

    function changePsk(ssid, psk) {
        if (ssid.length === 0 || psk.length < 8)
            return false;
        Quickshell.execDetached(["sh", "-c", `nmcli connection modify '${root.esc(ssid)}' wifi-sec.psk '${root.esc(psk)}'`]);
        return true;
    }

    function forgetNetwork(net) {
        root.editSsid = "";
        net?.forget();
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
