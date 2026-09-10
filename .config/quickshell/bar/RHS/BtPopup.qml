import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.customItems
import qs.services
import qs.themes

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

    // bluez discovery — quickshell's Bt service is reactive-only, so "fresh
    // pairs" have to be surfaced by briefly poking bluetoothctl instead
    property bool scanning: false

    function startScan() {
        if (root.scanning || root.adapter === null)
            return;
        root.scanning = true;
        scanTimer.restart();
        Quickshell.execDetached(["sh", "-c", "timeout 8 bluetoothctl scan on >/dev/null 2>&1; true"]);
    }

    Timer {
        id: scanTimer
        interval: 8200
        onTriggered: root.scanning = false
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
            implicitWidth: 16
            implicitHeight: 16
        }
    }

    component DeviceRow: Item {
        id: drow
        required property var modelData

        readonly property bool isConnected: modelData?.connected === true
        readonly property bool isBlocked: modelData?.blocked === true
        readonly property bool isPairing: modelData?.pairing === true
        readonly property bool isPaired: modelData?.paired === true
        readonly property color stateColor: isBlocked ? "#ff5555" : isConnected ? "#50fa7b" : isPairing ? "#f1fa8c" : Themes.muted
        readonly property string stateWord: isBlocked ? "blocked" : isConnected ? "connected" : isPairing ? "pairing…" : isPaired ? "paired" : "available"

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

        implicitHeight: 34
        Layout.fillWidth: true

        // whole-row toggle: connect / disconnect. sits behind the content so
        // interactive sub-controls (battery, volume slider) still win
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

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            spacing: 7

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
                    font {
                        pixelSize: 11
                        family: "Symbols Nerd Font Mono"
                    }
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
                    color: drow.isConnected ? Themes.fg : Themes.dim
                    elide: Text.ElideRight
                    font {
                        pixelSize: 11
                        bold: true
                        family: "Quicksand"
                    }
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
                    color: drow.isBlocked ? "#ff5555" : drow.isConnected ? "#50fa7b" : Themes.muted
                    elide: Text.ElideRight
                    font {
                        pixelSize: 9
                        family: "ZedMono Nerd Font"
                        letterSpacing: 0.5
                    }
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                visible: drow.modelData?.batteryAvailable === true
                spacing: 4

                Text {
                    text: "\uf240"
                    color: drow.modelData && drow.modelData.battery > 0.5 ? "#50fa7b" : drow.modelData && drow.modelData.battery > 0.2 ? "#f1fa8c" : "#ff5555"
                    font {
                        pixelSize: 10
                        family: "Symbols Nerd Font Mono"
                    }
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
                        color: drow.modelData && drow.modelData.battery > 0.5 ? "#50fa7b" : drow.modelData && drow.modelData.battery > 0.2 ? "#f1fa8c" : "#ff5555"
                    }
                }

                Text {
                    text: Math.round((drow.modelData?.battery ?? 0) * 100) + "%"
                    color: Themes.dim
                    font {
                        pixelSize: 9
                        family: "ZedMono Nerd Font"
                    }
                }
            }

            // media volume for the device's bluez player, when one is connected
            // and actually supports volume (some codecs/devices toggle only)
            RowLayout {
                visible: drow.btPlayer !== null && drow.btPlayer.volumeSupported
                spacing: 4

                Text {
                    text: "\uf028"
                    color: Themes.muted
                    font {
                        pixelSize: 9
                        family: "Symbols Nerd Font Mono"
                    }
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

            anchor.rect.y: root.host.height + 8

            implicitWidth: 300
            implicitHeight: card.implicitHeight + 28

            Rectangle {
                anchors.fill: parent
                focus: true
                radius: 12
                color: Themes.popupCardBg
                border.width: 1
                border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.3)

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
                            implicitWidth: 15
                            implicitHeight: 15
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "bluetooth"
                            color: Themes.fg
                            font {
                                pixelSize: 12
                                bold: true
                                family: "Quicksand"
                            }
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
                                font {
                                    pixelSize: 8
                                    bold: true
                                    family: "ZedMono Nerd Font"
                                }
                            }
                        }

                        // adapter power — textless switch (fill + knob) toggles
                        // the radio; the knob state mirrors bluez' adapter state
                        Rectangle {
                            visible: root.adapter !== null
                            Layout.alignment: Qt.AlignVCenter
                            property int trackW: 34

                            implicitWidth: trackW
                            implicitHeight: 20
                            radius: height / 2
                            color: Bt.enabled ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: Bt.enabled ? Themes.accent : Qt.rgba(1, 1, 1, 0.1)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: Bt.enabled ? parent.width - height - 2 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.height - 4
                                height: parent.height - 4
                                radius: width / 2
                                color: Bt.enabled ? Themes.accent : Themes.muted

                                Behavior on anchors.leftMargin {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MiscState.setBtRadio(!Bt.enabled)
                            }
                        }

                        // scan-refresh — bounded bluetoothctl discovery so
                        // unpaired devices nearby show up in the list
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter

                            implicitWidth: 22
                            implicitHeight: 20
                            radius: 6
                            color: root.scanning ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: root.scanning ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf021"
                                color: root.scanning ? Themes.accent : Themes.muted
                                font {
                                    pixelSize: 10
                                    family: "Symbols Nerd Font Mono"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startScan()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        visible: root.devices.length > 0
                        color: Themes.separator
                    }

                    Repeater {
                        model: root.devices
                        delegate: DeviceRow {}
                    }

                    // empty state — the segmented switch already communicates
                    // power state, so no redundant "bluetooth is off" wording
                    Text {
                        visible: root.devices.length === 0
                        text: !root.adapter ? "no bluetooth adapter found" : "no devices paired yet"
                        color: Themes.muted
                        font {
                            pixelSize: 10
                            family: "Quicksand"
                            italic: true
                        }
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
