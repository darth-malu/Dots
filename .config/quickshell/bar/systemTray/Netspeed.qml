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
        property real ethRxTotal: 0
        property real ethTxTotal: 0

        readonly property real totalDown: ethRxTotal
        readonly property real totalUp: ethTxTotal

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
            rxHistory.push(rx);
            txHistory.push(tx);
            if (rxHistory.length > historyMax)
                rxHistory.shift();
            if (txHistory.length > historyMax)
                txHistory.shift();
            graphTick++;
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
            running: NetworkState.netspeedVisible || NetworkState.netPopupVisible
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

            // ── Wifi icon + own click zone ──
            Item {
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

            // ── Ethernet icon + own click zone ──
            Item {
                implicitWidth: ethIco.width
                implicitHeight: ethIco.height
                Layout.alignment: Qt.AlignVCenter

                SvgIcon {
                    id: ethIco
                    anchors.centerIn: parent
                    icon: NetworkState.ethIcon
                    color: NetworkState.ethColor
                    width: 14
                    height: 14
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

                        InfoRow {
                            label: "iface"
                            value: root.ethIfName.length > 0 ? root.ethIfName : "-"
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

                        InfoRow {
                            visible: NetworkState.ethernet !== null
                            label: "eth"
                            value: root.ethUp ? (NetworkState.ethernet?.linkSpeed ? "linked · " + NetworkState.ethernet.linkSpeed + " Mb/s" : "linked") : "no link"
                            valueColor: root.ethUp ? "#8be9fd" : "#6272a4"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: "#343746"
                        }

                        InfoRow {
                            label: "total ↓"
                            value: root.fmtBytes(root.totalDown)
                            valueColor: "#bd93f9"
                        }

                        InfoRow {
                            label: "total ↑"
                            value: root.fmtBytes(root.totalUp)
                            valueColor: "#ff79c6"
                        }

                        SpeedBar {
                            label: "download"
                            glyph: "\uf063"
                            accent: "#bd93f9"
                            rate: root.online ? root.rxRate : 0
                            peak: root.peakRx
                            history: root.rxHistory
                            tick: root.graphTick
                        }

                        SpeedBar {
                            label: "upload"
                            glyph: "\uf062"
                            accent: "#ff79c6"
                            rate: root.online ? root.txRate : 0
                            peak: root.peakTx
                            history: root.txHistory
                            tick: root.graphTick
                        }
                    }
                }
            }
        }

        WifiPopup {
            host: loaderBig.host
            anchorItem: root
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

    component RateGraph: Item {
        id: graph

        property var history
        property real peak: 1
        property color accent: "#bd93f9"
        property int tick

        Layout.fillWidth: true
        implicitHeight: 38
        clip: true

        onTickChanged: paintCanvas.requestPaint()
        onWidthChanged: paintCanvas.requestPaint()

        Text {
            z: 1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 1
            text: root.fmtRate(graph.peak)
            color: Qt.rgba(graph.accent.r, graph.accent.g, graph.accent.b, 0.75)
            font {
                pixelSize: 8
                bold: true
                family: "ZedMono Nerd Font"
            }
        }

        Canvas {
            id: paintCanvas
            anchors.fill: parent
            antialiasing: true
            renderStrategy: Canvas.Immediate

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.lineWidth = 1;
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06);
                for (let i = 1; i <= 3; i++) {
                    ctx.beginPath();
                    ctx.moveTo(0, Math.round(height * i / 4));
                    ctx.lineTo(width, Math.round(height * i / 4));
                    ctx.stroke();
                }
                const h = graph.history ?? [];
                if (h.length < 2)
                    return;
                const stepX = width / (root.historyMax - 1);
                const baseY = height;
                const scale = Math.max(graph.peak, 0.001);
                const yAt = i => height - Math.min(1, h[i] / scale) * (height - 2) - 1;

                ctx.beginPath();
                ctx.moveTo(0, baseY);
                for (let i = 0; i < h.length; i++)
                    ctx.lineTo(i * stepX, yAt(i));
                ctx.lineTo((h.length - 1) * stepX, baseY);
                ctx.closePath();

                const grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, Qt.rgba(graph.accent.r, graph.accent.g, graph.accent.b, 0.32));
                grad.addColorStop(1, Qt.rgba(graph.accent.r, graph.accent.g, graph.accent.b, 0.02));
                ctx.fillStyle = grad;
                ctx.fill();

                ctx.beginPath();
                for (let i = 0; i < h.length; i++) {
                    if (i === 0)
                        ctx.moveTo(0, yAt(i));
                    else
                        ctx.lineTo(i * stepX, yAt(i));
                }
                ctx.strokeStyle = graph.accent;
                ctx.lineWidth = 1.5;
                ctx.stroke();
            }
        }
    }

    component SpeedBar: ColumnLayout {
        id: sbar
        property string label
        property string glyph
        property color accent
        property real rate
        property real peak
        property var history
        property int tick

        spacing: 5
        Layout.fillWidth: true

        RowLayout {
            spacing: 6
            Layout.fillWidth: true

            Text {
                text: sbar.glyph
                color: sbar.accent
                font {
                    pixelSize: 11
                    family: "Symbols Nerd Font Mono"
                }
            }

            Text {
                text: sbar.label
                color: "#b8bfcb"
                font {
                    pixelSize: 9
                    bold: true
                    family: "Quicksand"
                    letterSpacing: 1
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.fmtRate(sbar.rate)
                color: sbar.accent
                font {
                    pixelSize: 12
                    bold: true
                    family: "ZedMono Nerd Font"
                }
            }

            Text {
                text: sbar.rate >= 1000 ? "Gbps" : "Mbps"
                color: "#6272a4"
                font {
                    pixelSize: 9
                    family: "ZedMono Nerd Font"
                }
            }
        }

        RateGraph {
            history: sbar.history
            peak: sbar.peak
            accent: sbar.accent
            tick: sbar.tick
        }
    }
}
