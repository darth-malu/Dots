import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.customItems
import qs.services

BarBlock {
    id: root

    required property var host

    readonly property var adapter: Bt.adapter
    readonly property var devices: {
        const list = [...Bt.devices];
        list.sort((a, b) => ((b.connected === true) - (a.connected === true)) || String(a.name).localeCompare(String(b.name)));
        return list;
    }

    implicitWidth: 15
    implicitHeight: 15

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            NetworkState.btPopupVisible = !NetworkState.btPopupVisible;
    }

    onRightClicked: NetworkState.netspeedVisible = !NetworkState.netspeedVisible

    content: RowLayout {
        spacing: 0

        SvgIcon {
            icon: Bt.btIcon
            color: Bt.btColor
            width: 13
            height: 13
        }
    }

    component DeviceRow: RowLayout {
        id: drow
        required property var modelData

        readonly property bool isConnected: modelData?.connected === true
        readonly property color stateColor: modelData?.blocked === true ? "#f38ba8"
            : isConnected ? "#a6e3a1"
            : modelData?.pairing === true ? "#f9e2af"
            : "#6c7086"

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

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 6
            implicitHeight: 6
            radius: 3
            color: drow.stateColor
        }

        Text {
            text: drow.modelData?.name || drow.modelData?.deviceName || drow.modelData?.address || "?"
            color: drow.isConnected ? "#cdd6f4" : "#a6adc8"
            elide: Text.ElideRight
            font { pixelSize: 11; family: "Quicksand" }
            Layout.fillWidth: true
        }

        RowLayout {
            visible: drow.modelData?.batteryAvailable === true
            spacing: 3

            Text {
                text: "\uf240"
                color: drow.modelData && drow.modelData.battery > 0.5 ? "#a6e3a1"
                    : drow.modelData && drow.modelData.battery > 0.2 ? "#f9e2af"
                    : "#f38ba8"
                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
            }

            Text {
                text: Math.round((drow.modelData?.battery ?? 0) * 100) + "%"
                color: "#a6adc8"
                font { pixelSize: 9; family: "ZedMono Nerd Font" }
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

            implicitWidth: 250
            implicitHeight: card.implicitHeight + 28

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#1e1e2e"
                border.width: 1
                border.color: Qt.rgba(0.80, 0.65, 0.97, 0.3)

                Shortcut {
                    sequence: "Escape"
                    onActivated: NetworkState.btPopupVisible = false
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: NetworkState.btPopupVisible = false
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
                            text: "\uf294"
                            color: root.adapter ? "#89b4fa" : "#585b70"
                            font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                        }

                        Text {
                            text: "Bluetooth"
                            color: "#cdd6f4"
                            font { pixelSize: 12; bold: true; family: "Quicksand" }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: pillText.implicitWidth + 16
                            implicitHeight: 18
                            radius: 9
                            color: !root.adapter ? Qt.rgba(108 / 255, 112 / 255, 134 / 255, 0.14)
                                : Bt.connected ? Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.14)
                                : Bt.enabled ? Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.14)
                                : Qt.rgba(108 / 255, 112 / 255, 134 / 255, 0.14)

                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                text: !root.adapter ? "no adapter"
                                    : Bt.connected ? "connected"
                                    : Bt.enabled ? "idle"
                                    : "off"
                                color: !root.adapter ? "#6c7086"
                                    : Bt.connected ? "#a6e3a1"
                                    : Bt.enabled ? "#89b4fa"
                                    : "#6c7086"
                                font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#313244"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "adapter"
                            color: "#6c7086"
                            font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            Layout.preferredWidth: 56
                        }

                        Text {
                            text: root.adapter ? (Bt.enabled ? "powered" : "disabled") : "unavailable"
                            color: root.adapter ? (Bt.enabled ? "#cdd6f4" : "#585b70") : "#585b70"
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
                            color: Bt.enabled ? Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.35) : "#313244"

                            Rectangle {
                                x: Bt.enabled ? parent.width - width - 2 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: Bt.enabled ? "#89b4fa" : "#6c7086"

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
                        color: "#313244"
                    }

                    Repeater {
                        model: root.devices
                        delegate: DeviceRow {}
                    }

                    Text {
                        visible: root.devices.length === 0
                        text: !root.adapter ? "no bluetooth adapter found" : (Bt.enabled ? "no known devices" : "bluetooth is off")
                        color: "#585b70"
                        font { pixelSize: 10; family: "Quicksand"; italic: true }
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
