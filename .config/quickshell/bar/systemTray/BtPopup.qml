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
        readonly property color stateColor: modelData?.blocked === true ? "#ff5555"
            : isConnected ? "#50fa7b"
            : modelData?.pairing === true ? "#f1fa8c"
            : "#6272a4"

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
            color: drow.isConnected ? "#f8f8f2" : "#b8bfcb"
            elide: Text.ElideRight
            font { pixelSize: 11; family: "Quicksand" }
            Layout.fillWidth: true
        }

        RowLayout {
            visible: drow.modelData?.batteryAvailable === true
            spacing: 3

            Text {
                text: "\uf240"
                color: drow.modelData && drow.modelData.battery > 0.5 ? "#50fa7b"
                    : drow.modelData && drow.modelData.battery > 0.2 ? "#f1fa8c"
                    : "#ff5555"
                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
            }

            Text {
                text: Math.round((drow.modelData?.battery ?? 0) * 100) + "%"
                color: "#b8bfcb"
                font { pixelSize: 9; family: "ZedMono Nerd Font" }
            }
        }
    }

    LazyLoader {
        loading: true

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
                color: "#282a36"
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

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
                        spacing: 8

                        Text {
                            text: "adapter"
                            color: "#6272a4"
                            font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            Layout.preferredWidth: 56
                        }

                        Text {
                            text: root.adapter ? (Bt.enabled ? "powered" : "disabled") : "unavailable"
                            color: root.adapter ? (Bt.enabled ? "#f8f8f2" : "#6272a4") : "#6272a4"
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
