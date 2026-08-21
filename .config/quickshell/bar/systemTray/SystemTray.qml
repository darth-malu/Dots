pragma ComponentBehavior: Bound
import Quickshell
import qs.bar
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.customItems
import QtQuick.Effects
// import qs.themes import qs.bar
import qs.services

RowLayout {
    id: root

    Layout.alignment: Qt.AlignVCenter

    required property var host

    PipewireBlock {
        visible: MiscState.toggleVolume
    }

    Loader {
        visible: active
        asynchronous: true
        active: true
        sourceComponent: connections
        Layout.fillHeight: true
        // Layout.fillWidth: true
    }

    Loader {
        visible: active
        asynchronous: true
        active: MiscState.toggleSysTray

        Layout.fillHeight: true // ENSURE THE LOADER TAKES UP SPACE- enable clicking inside it 😀
        Layout.topMargin: 4
        Layout.bottomMargin: 3

        sourceComponent: sysBlock
    }

    Component {
        id: connections
        RowLayout {
            // spacing: 4
            // anchors.fill: parent

            BarBlock {
                id: wifiBlock
                implicitWidth: 15
                implicitHeight: 15
                color: "transparent"
                content: RowLayout {
                    spacing: 4
                    SvgIcon {
                        icon: Network.wifiIcon
                    }
                }

                onClicked: mouse => {
                    // mouse.accepted = true;
                    if (mouse.button === Qt.LeftButton) {
                        NetworkState.netspeedVisible = !NetworkState.netspeedVisible;
                    }
                }
            }
            BarBlock {
                id: ethernetBlock
                implicitWidth: 10
                implicitHeight: 10
                color: "transparent"
                content: RowLayout {
                    spacing: 4
                    SvgIcon {
                        icon: Network.ethIcon
                    }
                }

                onClicked: mouse => {
                    // mouse.accepted = true;
                    if (mouse.button === Qt.LeftButton) {
                        NetworkState.netspeedVisible = !NetworkState.netspeedVisible;
                    }
                }
            }

            Netspeed {}

            BarBlock {
                id: btBlock
                implicitWidth: 10
                implicitHeight: 10
                color: "transparent"
                content: RowLayout {
                    spacing: 4
                    SvgIcon {
                        icon: Bt.btIcon
                        color: Bt.btColor
                    }
                }

                onClicked: mouse => {
                    // mouse.accepted = true;
                    if (mouse.button === Qt.LeftButton) {
                        NetworkState.netspeedVisible = !NetworkState.netspeedVisible;
                    }
                }
            }
        }
    }

    Component {
        id: sysBlock
        BarBlock {
            implicitWidth: tray.implicitWidth
            implicitHeight: tray.implicitHeight

            color: Qt.rgba(1, 1, 1, 0.19)

            content: RowLayout {
                id: tray
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 2

                Repeater {
                    id: systemTrayRepeater
                    model: SystemTray.items

                    delegate: MouseArea {
                        id: delegate

                        required property SystemTrayItem modelData

                        property alias item: delegate.modelData

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        implicitWidth: icon.implicitWidth + 4

                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                        hoverEnabled: true

                        onClicked: event => {
                            if (event.button == Qt.LeftButton) {
                                item.activate();
                            } else if (event.button == Qt.RightButton) {
                                menuAnchor.open();
                            } else if (event.button == Qt.MiddleButton) {
                                item.secondaryActivate();
                            }
                        }

                        IconImage {
                            id: icon
                            // anchors.verticalCenter: parent.verticalCenter
                            anchors.centerIn: parent
                            // Layout.alignment: Qt.AlignCenter
                            source: modelData.icon
                            implicitSize: 12
                            asynchronous: true
                        }

                        QsMenuAnchor {
                            // FIXME: Make The flickering stop
                            id: menuAnchor
                            menu: modelData.menu

                            anchor.window: delegate.QsWindow.window // Use root.QsWindow.window direct?
                            anchor.adjustment: PopupAdjustment.Flip

                            anchor.onAnchoring: {
                                const window = delegate.QsWindow.window;
                                const widgetRect = window.contentItem.mapFromItem(delegate, 0, delegate.height, delegate.width, delegate.height);

                                menuAnchor.anchor.rect = widgetRect;
                            }
                        }

                        // TODO make tooltip
                        /* Tooltip { */
                        /*   relativeItem: delegate.containsMouse ? delegate : null */

                        /*   Label { */
                        /*     text: delegate.item.tooltipTitle || delegate.item.id */
                        /*   } */
                        /* } */
                    }
                }
            }
        }
    }

    QuickSettings {
        host: barr
    }
}
