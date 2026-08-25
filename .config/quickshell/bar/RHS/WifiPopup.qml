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

    function signalColor(level) {
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
                ipProc.running = true;
                // bands rarely change — fetch lazily, only once per session
                if (!root.bandsLoaded && Networking.wifiEnabled)
                    bandProc.running = true;
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
        // current speed chip drawn inside the graph, top-right
        property string label: ""

        Layout.fillWidth: true
        implicitHeight: 34
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.03)
        clip: true

        onTickChanged: tcanvas.requestPaint()
        onWidthChanged: tcanvas.requestPaint()
        onLabelChanged: tcanvas.requestPaint()

        Text {
            anchors {
                right: parent.right
                top: parent.top
                margins: 4
            }
            text: tgraph.label
            visible: tgraph.label.length > 0
            color: tgraph.accent
            font {
                pixelSize: 9
                bold: true
                family: "ZedMono Nerd Font"
            }
        }

        Canvas {
            id: tcanvas

            anchors.fill: parent
            anchors.margins: 4
            antialiasing: true
            renderStrategy: Canvas.Immediate

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

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

    component NetRow: Rectangle {
        id: netrow

        required property var modelData

        readonly property bool isConnected: modelData?.connected === true
        readonly property bool isKnown: modelData?.known === true
        readonly property string ssidName: modelData?.name ?? ""
        readonly property bool hiddenNet: ssidName.length === 0
        readonly property bool editing: root.editSsid.length > 0 && root.editSsid === ssidName
        property bool showPw: false

        // stored password fetched from NetworkManager for the reveal button
        property string savedPw: ""

        // quickshell's WifiNetwork has no connectWithPsk — join via nmcli with feedback
        function submitPw() {
            const psk = pwField.text.trim();
            if (!netrow.modelData || psk.length < 8)
                return;
            root.passwordNetwork = null;
            pwField.clear();
            root.requestConnect(netrow.ssidName, psk);
        }

        radius: 8
        Layout.fillWidth: true
        // extra vertical breathing room for a comfortable list
        implicitHeight: netCol.implicitHeight + 16
        // the row being edited is isolated behind a purple tint; plain hover gets a subtle wash
        color: editing ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.14) : rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
        opacity: isConnected ? 1 : 0.9

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        onEditingChanged: {
            pskEdit.clear();
            showPw = false;
            savedPw = "";
        }

        // hover tracking that never steals clicks from the row's controls
        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            z: -1
        }

        ColumnLayout {
            id: netCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

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
                        root.requestConnect(netrow.ssidName, "");
                    } else {
                        // secured and unknown: ask for the password first
                        root.passwordNetwork = netrow.modelData;
                        pwField.forceActiveFocus();
                    }
                }
            }

            SignalBars {
                level: netrow.modelData?.signalStrength ?? 0
                litColor: root.signalColor(netrow.modelData?.signalStrength ?? 0)
                Layout.alignment: Qt.AlignBottom
            }

            Text {
                text: netrow.hiddenNet ? "hidden network" : netrow.ssidName
                color: netrow.hiddenNet ? "#6272a4" : netrow.isConnected && MiscState.wifiGreenName ? "#50fa7b" : "#f8f8f2"
                font.italic: netrow.hiddenNet
                elide: Text.ElideRight
                font {
                    pixelSize: 12
                    family: "Quicksand"
                    weight: Font.Medium
                }
                Layout.fillWidth: true
            }

            // wifi band tag (2.4G / 5G / 6G) from nmcli scan data — chip style
            Rectangle {
                visible: !netrow.hiddenNet && root.bandFor(netrow.ssidName).length > 0
                radius: 4
                color: "#343746"
                implicitWidth: bandText.implicitWidth + 10
                implicitHeight: 14

                Text {
                    id: bandText
                    anchors.centerIn: parent
                    text: root.bandFor(netrow.ssidName)
                    color: "#8be9fd"
                    font { pixelSize: 8; bold: true; family: "ZedMono Nerd Font" }
                }
            }

            // open lock marks open (unsecured) networks; secured ones stay unmarked
            Text {
                text: "\uf09c"
                visible: !netrow.hiddenNet && !root.needsPsk(netrow.modelData?.security ?? 11)
                color: "#6272a4"
                font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
            }

            // settings editor toggle for known networks — becomes a close button while editing
            Text {
                visible: netrow.isKnown && netrow.ssidName.length > 0
                text: netrow.editing ? "\uf00d" : "\uf044"
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

            // connected dot — rightmost indicator on the row
            Rectangle {
                visible: netrow.isConnected
                implicitWidth: 5
                implicitHeight: 5
                radius: 2.5
                color: "#50fa7b"
            }
        }

        // ── Password entry, encapsulated right below the clicked network ──
        Rectangle {
            visible: root.passwordNetwork === netrow.modelData
            Layout.fillWidth: true
            implicitHeight: pwCol.implicitHeight + 16
            radius: 4
            color: "#343746"

            ColumnLayout {
                id: pwCol

                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                Text {
                    text: `password · ${netrow.hiddenNet ? "hidden network" : netrow.ssidName}`
                    color: "#bd93f9"
                    elide: Text.ElideMiddle
                    font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                    Layout.fillWidth: true
                }

                TextField {
                    id: pwField

                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    echoMode: TextInput.Password
                    placeholderText: "enter password… (⏎ to connect)"
                    color: "#f8f8f2"
                    placeholderTextColor: "#6272a4"
                    font { pixelSize: 11; family: "Quicksand" }
                    background: Rectangle {
                        radius: 4
                        color: "#282a36"
                        border.color: pwField.activeFocus ? "#bd93f9" : "#6272a4"
                        border.width: 1
                    }
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true

                    Keys.onReturnPressed: netrow.submitPw()
                    Keys.onEnterPressed: netrow.submitPw()
                    Keys.onEscapePressed: root.passwordNetwork = null
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
                        // cyan while displaying the network's stored password
                        color: netrow.savedPw.length > 0 && pskEdit.text === netrow.savedPw ? "#8be9fd" : "#f8f8f2"
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

                    // reveal / hide the typed password — with an empty field it
                    // pulls the CURRENT stored password from NetworkManager
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
                            onClicked: {
                                if (pskEdit.text.length === 0) {
                                    if (netrow.savedPw.length > 0) {
                                        pskEdit.text = netrow.savedPw;
                                        netrow.showPw = true;
                                    } else {
                                        pwFetchProc.running = true;
                                    }
                                } else if (pskEdit.text === netrow.savedPw) {
                                    // hide / clear the stored-password view
                                    pskEdit.clear();
                                    netrow.showPw = false;
                                } else {
                                    netrow.showPw = !netrow.showPw;
                                }
                            }
                        }
                    }

                    // copy the stored password to the clipboard (wl-copy)
                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 6
                        color: copyMa.containsMouse ? Qt.rgba(139 / 255, 233 / 255, 253 / 255, 0.14) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\uf0c5"
                            color: copyMa.containsMouse ? "#8be9fd" : "#6272a4"
                            font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                        }

                        MouseArea {
                            id: copyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["sh", "-c",
                                `pw=$(nmcli -s -g 802-11-wireless-security.psk connection show '${root.esc(netrow.ssidName)}' | tr -d '\\n'); `
                                + `if [ -n "$pw" ]; then printf %s "$pw" | wl-copy && notify-send -a Shell 'Password copied' '${root.esc(netrow.ssidName)}'; `
                                + `else notify-send -a Shell 'No stored password' '${root.esc(netrow.ssidName)}'; fi`]);
                        }
                    }

                    Rectangle {
                        id: applyBtn

                        function applyClicked() {
                            if (root.changePsk(netrow.ssidName, pskEdit.text)) {
                                pskEdit.clear();
                                netrow.savedPw = "";
                                netrow.showPw = false;
                            }
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

        // fetches the stored psk for this connection (nmcli -s shows secrets)
        Process {
            id: pwFetchProc
            command: ["sh", "-c", `nmcli -s -g 802-11-wireless-security.psk connection show '${root.esc(netrow.ssidName)}'`]
            running: false

            stdout: SplitParser {
                onRead: data => {
                    netrow.savedPw = data.trim();
                    if (netrow.savedPw.length > 0) {
                        pskEdit.text = netrow.savedPw;
                        netrow.showPw = true;
                    }
                }
            }
        }
    }

    LazyLoader {
        loading: NetworkState.wifiPopupVisible

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
                focus: true
                radius: 12
                color: MiscState.popupCardBg
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.35)

                Keys.onEscapePressed: {
                    if (root.passwordNetwork)
                        root.passwordNetwork = null;
                    else if (root.editSsid.length > 0)
                        root.editSsid = "";
                    else
                        NetworkState.wifiPopupVisible = false;
                }

                ColumnLayout {
                    id: card
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    // ── Header zone — icon · iface name · graph toggle · power ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        Text {
                            text: "\uf1eb"
                            color: "#bd93f9"
                            font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                        }

                        Text {
                            visible: (root.adapter?.name ?? "").length > 0
                            text: root.adapter?.name ?? ""
                            color: "#f8f8f2"
                            font { pixelSize: 12; bold: true; family: "Quicksand" }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

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

                    // ── Connection zone — details & live traffic on a raised panel ──
                    // height = inner column + both margins (anchored children don't size parents)
                    Rectangle {
                        visible: root.showDetails || (NetworkState.wifiGraphEnabled && root.netRoot !== null)
                        Layout.fillWidth: true
                        implicitHeight: connZone.implicitHeight + 20
                        radius: 10
                        color: "#21222c"

                        ColumnLayout {
                            id: connZone
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 8

                            // current connection details
                            ColumnLayout {
                                visible: root.showDetails && NetworkState.wifiConnected
                                Layout.fillWidth: true
                                spacing: 5

                                Repeater {
                                    model: [
                                        { label: "ssid", value: NetworkState.activeNetwork?.name ?? "-" },
                                        { label: "band", value: root.bandFor(NetworkState.activeNetwork?.name ?? "") || "-" },
                                        { label: "signal", value: Math.round((NetworkState.activeNetwork?.signalStrength ?? 0) * 100) + "%" },
                                        { label: "security", value: NetworkState.activeNetwork != null ? root.secLabel(NetworkState.activeNetwork.security) : "-" },
                                        { label: "ipv4", value: root.wifiIp.length > 0 ? root.wifiIp : "-" },
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
                                            font { pixelSize: 12; bold: true; family: "ZedMono Nerd Font" }
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.showDetails && NetworkState.wifiConnected && NetworkState.wifiGraphEnabled && root.netRoot !== null
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: Qt.rgba(1, 1, 1, 0.06)
                            }

                            // upload/download traffic graphs + totals
                            ColumnLayout {
                                visible: NetworkState.wifiGraphEnabled && root.netRoot !== null
                                Layout.fillWidth: true
                                spacing: 5

                                RowLayout {
                                    visible: MiscState.showNetTotals || NetworkState.wifiGraphEnabled
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: `\u2193 ${root.netRoot.fmtBytes(root.netRoot.ifaceRxTotal)}`
                                        color: "#bd93f9"
                                        font { pixelSize: 10; bold: true; family: "ZedMono Nerd Font" }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: `\u2191 ${root.netRoot.fmtBytes(root.netRoot.ifaceTxTotal)}`
                                        color: "#ff79c6"
                                        font { pixelSize: 10; bold: true; family: "ZedMono Nerd Font" }
                                    }
                                }

                                // ── Live traffic graphs — current speed rendered inside each graph ──
                                TrafficGraph {
                                    accent: "#bd93f9"
                                    history: root.netRoot.rxHistory
                                    peak: root.netRoot.peakRx
                                    tick: root.netRoot.graphTick
                                    maxLen: root.netRoot.historyMax
                                    label: root.netRoot.fmtRate(root.netRoot.rxRate)
                                }

                                TrafficGraph {
                                    accent: "#ff79c6"
                                    history: root.netRoot.txHistory
                                    peak: root.netRoot.peakTx
                                    tick: root.netRoot.graphTick
                                    maxLen: root.netRoot.historyMax
                                    label: root.netRoot.fmtRate(root.netRoot.txRate)
                                }
                            }
                        }
                    }

                    // ── Networks zone — flat list split into known / available ──
                    ColumnLayout {
                        visible: Networking.wifiEnabled && root.networks.length > 0
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            visible: root.knownNets.length > 0
                            text: `known \u00b7 ${root.knownNets.length}`
                            color: "#6272a4"
                            font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            Layout.leftMargin: 4
                        }

                        Repeater {
                            model: root.knownNets
                            delegate: NetRow {}
                        }

                        Text {
                            visible: root.unknownNets.length > 0
                            text: `available \u00b7 ${root.unknownNets.length}`
                            color: "#6272a4"
                            font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            Layout.leftMargin: 4
                            Layout.topMargin: 6
                        }

                        Repeater {
                            model: root.unknownNets
                            delegate: NetRow {}
                        }
                    }

                    Text {
                        visible: Networking.wifiEnabled && root.networks.length === 0 && root.adapter !== null
                        text: "scanning for networks\u2026"
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

    // current default-route IPv4 (wifi or ethernet) for the details panel
    property string wifiIp: ""

    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.*src \\([0-9.]\\+\\).*/\\1/p'"]
        running: false

        stdout: SplitParser {
            onRead: data => root.wifiIp = data.trim()
        }
    }

    // ssid -> band ("2.4G" / "5G" / "6G") parsed from the last wifi scan.
    // fetched lazily: one cheap nmcli pass, parsed in a single batch on exit
    property var bandMap: ({})
    property bool bandsLoaded: false

    function bandFor(ssid) {
        return root.bandMap[ssid] ?? "";
    }

    function bandLabel(mhz) {
        const f = parseInt(mhz) || 0;
        if (f >= 5945)
            return "6G";
        if (f >= 3000)
            return "5G";
        return "2.4G";
    }

    Process {
        id: bandProc
        command: ["sh", "-c", "nmcli -t -f SSID,FREQ dev wifi list --rescan no"]
        running: false

        property string buf: ""

        stdout: SplitParser {
            onRead: data => bandProc.buf += data + "\n"
        }

        onExited: {
            const map = {};
            for (const line of bandProc.buf.trim().split("\n")) {
                const i = line.lastIndexOf(":");
                if (i <= 0)
                    continue;
                const ssid = line.slice(0, i);
                if (ssid.length === 0 || map[ssid] != null)
                    continue;
                map[ssid] = root.bandLabel(line.slice(i + 1));
            }
            root.bandMap = map;
            root.bandsLoaded = true;
            bandProc.buf = "";
        }
    }

    function esc(s) {
        return String(s).replace(/'/g, "'\\''");
    }

    // ── connect with feedback — nmcli stderr surfaces as a notification ──
    property string pendingSsid: ""

    function requestConnect(ssid, psk) {
        if (!ssid || ssid.length === 0)
            return;
        pendingSsid = ssid;
        connProc.cmd = "nmcli --wait 15 dev wifi connect '" + esc(ssid) + "'"
            + (psk && psk.length > 0 ? " password '" + esc(psk) + "'" : "");
        connProc.running = true;
    }

    Process {
        id: connProc
        property string cmd: ""
        property string errBuf: ""
        command: ["sh", "-c", connProc.cmd]
        running: false

        stdout: SplitParser {
            onRead: data => {}
        }

        stderr: SplitParser {
            onRead: data => connProc.errBuf += data
        }

        onExited: {
            if (connProc.cmd.length === 0)
                return;
            const trimmed = connProc.errBuf.trim();
            if (trimmed.length > 0 && !/successfully activated|Connection activation/i.test(trimmed)) {
                const msg = trimmed.split("\n").pop() || "connection failed";
                Quickshell.execDetached(["notify-send", "-a", "Shell", "Wi-Fi · " + root.pendingSsid, msg]);
            }
            connProc.errBuf = "";
            connProc.cmd = "";
        }
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
}
