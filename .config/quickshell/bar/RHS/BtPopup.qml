import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.customItems
import qs.services

BarBlock {
    id: root

    visible: MiscState.showBluetooth

    // module off → its popup window must not linger
    onVisibleChanged: if (!visible)
        NetworkState.btPopupVisible = false
    required property var host

    readonly property var adapter: Bt.adapter
    readonly property var devices: {
        const list = [...Bt.devices];
        list.sort((a, b) => ((b.connected === true) - (a.connected === true)) || String(a.name).localeCompare(String(b.name)));
        return list;
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            NetworkState.btPopupVisible = !NetworkState.btPopupVisible;
    }

    onRightClicked: NetworkState.netspeedVisible = !NetworkState.netspeedVisible

    content: RowLayout {
        spacing: 6

        SvgIcon {
            icon: Bt.btIcon
            color: Bt.btColor
            width: 16
            height: 16
        }
    }

    component DeviceRow: RowLayout {
        id: drow
        required property var modelData

        readonly property bool isConnected: modelData?.connected === true
        readonly property bool isBlocked: modelData?.blocked === true
        readonly property bool isPairing: modelData?.pairing === true
        readonly property bool isPaired: modelData?.paired === true
        readonly property color stateColor: isBlocked ? "#ff5555"
            : isConnected ? "#50fa7b"
            : isPairing ? "#f1fa8c"
            : "#6272a4"
        readonly property string stateWord: isBlocked ? "blocked"
            : isConnected ? "connected"
            : isPairing ? "pairing…"
            : isPaired ? "paired"
            : "available"

        // bluez icon class -> nerd font glyph
        readonly property string devGlyph: {
            const s = String(modelData?.icon ?? "");
            if (s.includes("headset") || s.includes("headphones") || s.includes("audio"))
                return "\uf025";
            if (s.includes("keyboard"))
                return "\uf11c";
            if (s.includes("mouse") || s.includes("pointing"))
                return "\uf245";
            if (s.includes("phone"))
                return "\uf10b";
            if (s.includes("camera"))
                return "\uf030";
            if (s.includes("computer") || s.includes("laptop"))
                return "\uf109";
            if (s.includes("watch"))
                return "\uf2a2";
            return "\uf294";
        }

        // human-readable device class from the bluez icon name
        readonly property string devType: {
            const s = String(modelData?.icon ?? "").replace(/^audio-|^input-/, "");
            return s.length > 0 ? s : "";
        }

        // the bluez media player exported by this device over MPRIS (for volume)
        readonly property var btPlayer: {
            if (!drow.isConnected)
                return null;
            const addr = String(drow.modelData?.address ?? "").replace(/:/g, "").toLowerCase();
            const nm = String(drow.modelData?.name ?? "").toLowerCase();
            const players = Mpris.players.values;
            for (let i = 0; i < players.length; i++) {
                const pid = String(players[i].id ?? "").toLowerCase();
                if ((addr.length > 0 && pid.includes(addr)) || (nm.length > 0 && pid.includes(nm)))
                    return players[i];
            }
            return null;
        }

        spacing: 7
        Layout.fillWidth: true

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!drow.modelData)
                    return;
                if (drow.isConnected)
                    drow.modelData.disconnect();
                else
                    drow.modelData.connect();
            }
        }

        // device-type glyph in a state-tinted tile
        Rectangle {
            implicitWidth: 24
            implicitHeight: 24
            radius: 6
            color: Qt.rgba(drow.stateColor.r, drow.stateColor.g, drow.stateColor.b, drow.isConnected ? 0.14 : 0.07)

            Text {
                anchors.centerIn: parent
                text: drow.devGlyph
                color: drow.stateColor
                font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
                text: drow.modelData?.name || drow.modelData?.deviceName || drow.modelData?.address || "?"
                color: drow.isConnected ? "#f8f8f2" : "#b8bfcb"
                elide: Text.ElideRight
                font { pixelSize: 11; bold: true; family: "Quicksand" }
                Layout.fillWidth: true
            }

            // address · device class · state word — the informational line
            Text {
                text: {
                    const parts = [drow.modelData?.address ?? "?"];
                    if (drow.devType.length > 0)
                        parts.push(drow.devType);
                    parts.push(drow.stateWord);
                    return parts.join(" · ");
                }
                color: drow.isBlocked ? "#ff5555" : drow.isConnected ? "#50fa7b" : "#6272a4"
                elide: Text.ElideRight
                font { pixelSize: 9; family: "ZedMono Nerd Font"; letterSpacing: 0.5 }
                Layout.fillWidth: true
            }
        }

        RowLayout {
            visible: drow.modelData?.batteryAvailable === true
            spacing: 4

            Text {
                text: "\uf240"
                color: drow.modelData && drow.modelData.battery > 0.5 ? "#50fa7b"
                    : drow.modelData && drow.modelData.battery > 0.2 ? "#f1fa8c"
                    : "#ff5555"
                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
            }

            // mini battery bar
            Rectangle {
                implicitWidth: 26
                implicitHeight: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    width: parent.width * Math.min(Math.max(drow.modelData?.battery ?? 0, 0), 1)
                    height: parent.height
                    radius: 1.5
                    color: drow.modelData && drow.modelData.battery > 0.5 ? "#50fa7b"
                        : drow.modelData && drow.modelData.battery > 0.2 ? "#f1fa8c"
                        : "#ff5555"
                }
            }

            Text {
                text: Math.round((drow.modelData?.battery ?? 0) * 100) + "%"
                color: "#b8bfcb"
                font { pixelSize: 9; family: "ZedMono Nerd Font" }
            }
        }

        // media volume for the device's bluez player, when one is connected
        RowLayout {
            visible: drow.btPlayer !== null
            spacing: 4

            Text {
                text: "\uf028"
                color: "#6272a4"
                font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
            }

            Slider {
                from: 0
                to: 1
                stepSize: 0.01
                value: drow.btPlayer?.volume ?? 0
                onMoved: {
                    if (drow.btPlayer)
                        drow.btPlayer.volume = value;
                }
                implicitWidth: 56
            }
        }
    }

    LazyLoader {
        loading: NetworkState.btPopupVisible

        PopupWindow {
            id: btPopup
            visible: NetworkState.btPopupVisible
            grabFocus: true
            color: "transparent"

            anchor.window: root.host
            anchor.rect.x: {
                let globalPos = root.mapToGlobal(0, 0);
                return globalPos.x + (root.width / 2) - (width / 2);
            }

            anchor.rect.y: 33

            implicitWidth: 280
            implicitHeight: card.implicitHeight + 28

            Rectangle {
                anchors.fill: parent
                focus: true
                radius: 12
                color: MiscState.popupCardBg
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

                Keys.onEscapePressed: NetworkState.btPopupVisible = false

                ColumnLayout {
                    id: card
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    // ── Header: icon · title · connected count · power toggle ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        SvgIcon {
                            icon: Bt.btIcon
                            color: Bt.btColor
                            width: 15
                            height: 15
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "bluetooth"
                            color: "#f8f8f2"
                            font { pixelSize: 12; bold: true; family: "Quicksand" }
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: root.devices.filter(d => d.connected === true).length > 0
                            radius: 4
                            implicitWidth: connText.implicitWidth + 10
                            implicitHeight: 15

                            Text {
                                id: connText
                                anchors.centerIn: parent
                                text: root.devices.filter(d => d.connected === true).length + " connected"
                                color: "#50fa7b"
                                font { pixelSize: 8; bold: true; family: "ZedMono Nerd Font" }
                            }
                        }

                        Rectangle {
                            visible: root.adapter !== null
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 26
                            implicitHeight: 14
                            radius: 7
                            color: Bt.enabled ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.35) : "#343746"

                            Rectangle {
                                x: Bt.enabled ? parent.width - width - 2 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: Bt.enabled ? "#bd93f9" : "#6272a4"

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
                                onClicked: {
                                    if (root.adapter)
                                        root.adapter.enabled = !Bt.enabled;
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        visible: root.devices.length > 0
                        color: "#343746"
                    }

                    Repeater {
                        model: root.devices
                        delegate: DeviceRow {}
                    }

                    Text {
                        visible: root.devices.length === 0
                        text: !root.adapter ? "no bluetooth adapter found" : (Bt.enabled ? "no known devices" : "bluetooth is off")
                        color: "#6272a4"
                        font { pixelSize: 10; family: "Quicksand"; italic: true }
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
