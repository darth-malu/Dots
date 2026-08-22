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
    active: true
    visible: true

    sourceComponent: BarBlock {
        id: root

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        color: NetworkState.netspeedVisible ? Qt.rgba(0.74, 0.58, 0.98, 0.15) : "transparent"

        property int refreshInterval: 1000
        property string iface

        property real rxRate
        property real txRate
        property real rxPrev: 0
        property real txPrev: 0
        property real peakRx: 1
        property real peakTx: 1

        readonly property int historyMax: 60
        property var rxHistory: []
        property var txHistory: []
        property int graphTick: 0

        property string ipAddr: ""
        property string gateway: ""

        readonly property bool wifiUp: NetworkState.wifiConnected
        readonly property bool ethUp: NetworkState.ethernet?.hasLink ?? false
        readonly property bool online: wifiUp || ethUp

        readonly property string ethIfName: NetworkState.ethernet?.name ?? ""
        readonly property bool ethConnected: NetworkState.ethernet?.network?.connected ?? false
        property real ethRxTotal: 0
        property real ethTxTotal: 0

        function esc(s) {
            return String(s).replace(/'/g, "'\\''");
        }

        // ethernet connectivity toggle (header switch)
        function setEthPower(on) {
            if (root.ethIfName.length === 0)
                return;
            Quickshell.execDetached(["sh", "-c", `nmcli dev ${on ? "connect" : "disconnect"} '${root.esc(root.ethIfName)}'`]);
        }

        // byte counters of whichever interface is currently routed (wifi or eth)
        property real ifaceRxTotal: 0
        property real ifaceTxTotal: 0

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

        function fmtBytes(b) {
            if (!(b > 0))
                return "0 B";
            const units = ["B", "KB", "MB", "GB", "TB"];
            let i = 0;
            let v = b;
            while (v >= 1024 && i < units.length - 1) {
                v /= 1024;
                i++;
            }
            return (i === 0 ? Math.round(v) : v.toFixed(2)) + " " + units[i];
        }

        function resetRates() {
            rxPrev = 0;
            txPrev = 0;
            rxRate = 0;
            txRate = 0;
            rxHistory = [];
            txHistory = [];
            graphTick++;
        }

        function pushSample(rx, tx) {
            if (!root.graphsLive)
                return;
            rxHistory.push(rx);
            txHistory.push(tx);
            if (rxHistory.length > historyMax)
                rxHistory.shift();
            if (txHistory.length > historyMax)
                txHistory.shift();
            graphTick++;
        }

        // graphs only accumulate samples while one of the popup graphs is actually shown
        readonly property bool wifiGraphs: NetworkState.wifiPopupVisible && NetworkState.wifiGraphEnabled
        readonly property bool ethGraphs: NetworkState.netPopupVisible && NetworkState.ethGraphsEnabled
        readonly property bool graphsLive: wifiGraphs || ethGraphs

        onGraphsLiveChanged: {
            if (!graphsLive) {
                rxHistory = [];
                txHistory = [];
                graphTick++;
            }
        }

        Connections {
            target: NetworkState

            function onNetspeedVisibleChanged() {
                root.resetRates();
            }

            function onNetPopupVisibleChanged() {
                if (NetworkState.netPopupVisible)
                    root.resetRates();
            }
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
                        let viaIndex = line.indexOf("via");
                        if (devIndex === -1)
                            return;
                        root.iface = line[devIndex + 1];
                        if (root.ethIfName.length > 0 && line[devIndex + 1] === root.ethIfName)
                            root.gateway = viaIndex !== -1 ? line[viaIndex + 1] : "";
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
                            root.pushSample(root.rxRate, root.txRate);
                        }

                        root.rxPrev = rx;
                        root.txPrev = tx;

                        root.ifaceRxTotal = rx;
                        root.ifaceTxTotal = tx;
                    }

                    if (root.ethIfName.length > 0 && data.startsWith(root.ethIfName + ":")) {
                        const parts = data.split(/\s+/);
                        root.ethRxTotal = parseInt(parts[1]);
                        root.ethTxTotal = parseInt(parts[9]);
                    }
                }
            }
        }

        Process {
            id: addrProc
            command: ["sh", "-c", "ip -o addr show scope global"]
            running: false

            stdout: SplitParser {
                onRead: data => {
                    const parts = data.trim().split(/\s+/);
                    if (parts[1] !== root.ethIfName)
                        return;
                    if (parts[2] === "inet")
                        root.ipAddr = parts[3].split("/")[0];
                }
            }
        }

        onEthIfNameChanged: {
            ipAddr = "";
            gateway = "";
            addrProc.running = true;
        }

        Timer {
            interval: root.refreshInterval
            // bar mode polls whenever shown; popups poll while open (graphs gate history only)
            running: NetworkState.netspeedVisible || NetworkState.netPopupVisible || root.wifiGraphs
            repeat: true
            triggeredOnStart: true
            onTriggered: () => {
                defaultInterface.running = true;
                getRxTxBytes.running = true;
            }
        }

        Timer {
            interval: 10000
            running: NetworkState.netspeedVisible || NetworkState.netPopupVisible
            repeat: true
            triggeredOnStart: true
            onTriggered: addrProc.running = true
        }

        onRightClicked: NetworkState.netspeedVisible = !NetworkState.netspeedVisible

        content: RowLayout {
            id: netRow
            spacing: 6

            // ── Wifi icon — shown whenever the cable is NOT linked (exactly one net icon at all times) ──
            Item {
                visible: NetworkState.ethernet?.hasLink !== true
                implicitWidth: wifiIco.width
                implicitHeight: wifiIco.height
                Layout.alignment: Qt.AlignVCenter

                SvgIcon {
                    id: wifiIco
                    anchors.centerIn: parent
                    icon: NetworkState.wifiIcon
                    color: NetworkState.wifiColor
                    width: 16
                    height: 16
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkState.wifiPopupVisible = !NetworkState.wifiPopupVisible
                }
            }

            // ── Ethernet icon — linked cable takes over the slot and hides wifi ──
            Item {
                visible: NetworkState.ethernet?.hasLink === true
                implicitWidth: ethIco.width
                implicitHeight: ethIco.height
                Layout.alignment: Qt.AlignVCenter

                SvgIcon {
                    id: ethIco
                    anchors.centerIn: parent
                    icon: NetworkState.ethIcon
                    color: NetworkState.ethColor
                    width: 16
                    height: 16
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkState.netPopupVisible = !NetworkState.netPopupVisible
                }
            }

            RowLayout {
                visible: NetworkState.netspeedVisible
                spacing: 5

                Item {
                    Layout.preferredWidth: 2
                }

                BarText {
                    text: root.rxRate === 0 ? "-" : root.fmtRate(root.rxRate)
                    color: "#bd93f9"
                    font {
                        pixelSize: 10
                        family: "ZedMono Nerd Font"
                    }
                }

                Rectangle {
                    visible: false
                    implicitWidth: 1
                    implicitHeight: 10
                    color: "#44475a"
                }

                BarText {
                    text: root.txRate === 0 ? "-" : root.fmtRate(root.txRate)
                    color: "#ff79c6"
                    font {
                        pixelSize: 10
                        family: "ZedMono Nerd Font"
                    }
                }
            }
        }

        LazyLoader {
            loading: true

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

                implicitWidth: 268
                implicitHeight: card.implicitHeight + 28

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    radius: 12
                    color: "#282a36"
                    border.width: 1
                    border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

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

                        // ── Header: link details left · graph toggle + connectivity switch right ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                spacing: 2

                                RowLayout {
                                    spacing: 6

                                    Rectangle {
                                        implicitWidth: 6
                                        implicitHeight: 6
                                        radius: 3
                                        color: root.ethUp ? "#50fa7b" : "#6272a4"
                                    }

                                    Text {
                                        text: root.ethIfName.length > 0 ? root.ethIfName : "no device"
                                        color: "#f8f8f2"
                                        font { pixelSize: 11; bold: true; family: "Quicksand" }
                                    }
                                }

                                Text {
                                    text: root.ethUp
                                        ? (NetworkState.ethernet?.linkSpeed ? `linked · ${NetworkState.ethernet.linkSpeed} Mb/s` : "linked")
                                        : root.ethConnected ? "connecting…" : "no link"
                                    color: root.ethUp ? "#8be9fd" : "#6272a4"
                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 22
                                implicitHeight: 18
                                radius: 6
                                color: graphBtnMouse.containsMouse || NetworkState.ethGraphsEnabled ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.16) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf1fe"
                                    color: NetworkState.ethGraphsEnabled ? "#bd93f9" : "#6272a4"
                                    font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                                }

                                MouseArea {
                                    id: graphBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NetworkState.ethGraphsEnabled = !NetworkState.ethGraphsEnabled
                                }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 26
                                implicitHeight: 14
                                radius: 7
                                color: root.ethConnected ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.35) : "#343746"

                                Rectangle {
                                    x: root.ethConnected ? parent.width - width - 2 : 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: 10
                                    implicitHeight: 10
                                    radius: 5
                                    color: root.ethConnected ? "#bd93f9" : "#6272a4"

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
                                    onClicked: root.setEthPower(!root.ethConnected)
                                }
                            }
                        }


                        InfoRow {
                            label: "ipv4"
                            value: root.ipAddr.length > 0 ? root.ipAddr : "unavailable"
                            valueColor: root.ipAddr.length > 0 ? "#f8f8f2" : "#6272a4"
                        }

                        InfoRow {
                            label: "gateway"
                            value: root.gateway.length > 0 ? root.gateway : "-"
                        }


                        // ── Live traffic graphs — total on the left, live rates on the right ──
                        RowLayout {
                            visible: root.ethGraphs
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: `total ↓ ${root.fmtBytes(root.ethRxTotal)}`
                                color: "#6272a4"
                                font { pixelSize: 9; family: "ZedMono Nerd Font" }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: `↓ ${root.fmtRate(root.rxRate)}`
                                color: "#bd93f9"
                                font { pixelSize: 9; bold: true; family: "ZedMono Nerd Font" }
                            }

                            Text {
                                text: `↑ ${root.fmtRate(root.txRate)}`
                                color: "#ff79c6"
                                font { pixelSize: 9; bold: true; family: "ZedMono Nerd Font" }
                            }
                        }

                        TrafficGraph {
                            visible: root.ethGraphs
                            accent: "#bd93f9"
                            history: root.rxHistory
                            peak: root.peakRx
                            tick: root.graphTick
                            maxLen: root.historyMax
                        }

                        TrafficGraph {
                            visible: root.ethGraphs
                            accent: "#ff79c6"
                            history: root.txHistory
                            peak: root.peakTx
                            tick: root.graphTick
                            maxLen: root.historyMax
                        }
                    }
                }
            }
        }

        WifiPopup {
            host: loaderBig.host
            anchorItem: root
            netRoot: root
        }
    }

    component InfoRow: RowLayout {
        id: irow
        property string label
        property string value
        property color valueColor: "#f8f8f2"

        spacing: 8
        Layout.fillWidth: true

        Text {
            text: irow.label
            color: "#6272a4"
            font {
                pixelSize: 9
                bold: true
                family: "Quicksand"
                letterSpacing: 1
            }
            Layout.preferredWidth: 56
        }

        Text {
            text: irow.value
            color: irow.valueColor
            elide: Text.ElideRight
            font {
                pixelSize: 11
                family: "ZedMono Nerd Font"
            }
            Layout.fillWidth: true
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
}
