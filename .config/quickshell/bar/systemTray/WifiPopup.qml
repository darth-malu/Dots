import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.services

Item {
    id: root

    required property var host

    property Item anchorItem

    readonly property var adapter: NetworkState.adapter

    readonly property var networks: {
        const list = [...(root.adapter?.networks.values ?? [])];
        list.sort((a, b) => ((b.connected === true) - (a.connected === true))
            || ((b.signalStrength ?? 0) - (a.signalStrength ?? 0))
            || String(a.ssid ?? "").localeCompare(String(b.ssid ?? "")));
        return list;
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

            implicitWidth: 260
            implicitHeight: card.implicitHeight + 28

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#282a36"
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.35)

                Shortcut {
                    sequence: "Escape"
                    onActivated: NetworkState.wifiPopupVisible = false
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "\uf1eb"
                            color: root.adapter ? "#bd93f9" : "#6272a4"
                            font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                        }

                        Text {
                            text: "Wi-Fi"
                            color: "#f8f8f2"
                            font { pixelSize: 12; bold: true; family: "Quicksand" }
                        }

                        Item { Layout.fillWidth: true }

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
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#44475a"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "wifi"
                            color: "#6272a4"
                            font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            Layout.preferredWidth: 56
                        }

                        Text {
                            text: root.adapter ? (Networking.wifiEnabled ? "powered" : "disabled") : "unavailable"
                            color: root.adapter ? (Networking.wifiEnabled ? "#f8f8f2" : "#6272a4") : "#6272a4"
                            elide: Text.ElideRight
                            font { pixelSize: 11; family: "ZedMono Nerd Font" }
                            Layout.fillWidth: true
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

                            spacing: 7
                            Layout.fillWidth: true
                            opacity: isConnected ? 1 : 0.85

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!netrow.modelData)
                                        return;
                                    if (netrow.isConnected)
                                        netrow.modelData.disconnect();
                                    else
                                        netrow.modelData.connect();
                                }
                            }

                            SignalBars {
                                level: netrow.modelData?.signalStrength ?? 0
                                litColor: root.signalColor(netrow.modelData?.signalStrength ?? 0, netrow.isConnected)
                                Layout.alignment: Qt.AlignBottom
                            }

                            Text {
                                text: netrow.modelData?.ssid ?? ""
                                color: netrow.isConnected ? "#f8f8f2" : "#b8bfcb"
                                elide: Text.ElideRight
                                font { pixelSize: 11; family: "Quicksand" }
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "\uf023"
                                visible: (netrow.modelData?.security ?? 0) !== 0
                                color: "#6272a4"
                                font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
                            }

                            Text {
                                text: "\uf00c"
                                visible: netrow.isConnected
                                color: "#50fa7b"
                                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                            }
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
}
