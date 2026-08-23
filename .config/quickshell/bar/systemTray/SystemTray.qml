pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.customItems
import qs.services
import qs.bar
import qs.bar.quicksettings

RowLayout {
    id: root

    Layout.alignment: Qt.AlignVCenter

    required property var host

    Loader {
        visible: active
        asynchronous: true
        active: true
        sourceComponent: connections
        Layout.alignment: Qt.AlignVCenter
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
            Netspeed {
                host: root.host
            }

            BtPopup {
                host: root.host
            }

            NotifCenter {
                host: root.host
            }
        }
    }
    Component {
        id: sysBlock
        BarBlock {
            interactive: false

            implicitWidth: tray.implicitWidth
            implicitHeight: tray.implicitHeight

            color: trayHover.hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.19)

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            HoverHandler {
                id: trayHover
            }

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
                        Layout.preferredWidth: Math.max(icon.implicitWidth + 8, 20)
                        Layout.alignment: Qt.AlignVCenter

                        readonly property bool hasMenu: item?.hasMenu ?? false
                        // menu only opens while this flag is armed — a stale
                        // QsMenuAnchor grabbing focus was closing it instantly
                        property bool menuArmed: false
                        onHasMenuChanged: if (!hasMenu) menuArmed = false

                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: delegate.pressed ? Qt.rgba(0.741, 0.576, 0.976, 0.35)
                                : delegate.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                                : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 110 }
                            }
                        }

                        onClicked: event => {
                            if (event.button == Qt.LeftButton) {
                                try { item.activate(); } catch (e) {}
                            } else if (event.button == Qt.RightButton) {
                                if (delegate.hasMenu) {
                                    delegate.menuArmed = true;
                                    menuAnchor.open();
                                } else {
                                    try { item.activate(); } catch (e) {}
                                }
                            } else if (event.button == Qt.MiddleButton) {
                                try { item.secondaryActivate(); } catch (e) {}
                            }
                        }

                        IconImage {
                            id: icon
                            anchors.centerIn: parent
                            source: modelData.icon
                            implicitSize: 13
                            asynchronous: true
                        }

                        QsMenuAnchor {
                            id: menuAnchor
                            menu: delegate.menuArmed ? modelData.menu : null

                            anchor.window: delegate.QsWindow.window
                            anchor.adjustment: PopupAdjustment.Flip

                            anchor.onAnchoring: {
                                const window = delegate.QsWindow.window;
                                const widgetRect = window.contentItem.mapFromItem(delegate, 0, delegate.height, delegate.width, 0);

                                menuAnchor.anchor.rect = widgetRect;
                            }
                        }
                    }
                }
            }
        }
    }

    QuickSettings {
        host: root.host
    }

    // live countdown pill while a reboot/shutdown timer is armed —
    // left-click cancels it
    BarBlock {
        visible: PowerTimer.active

        interactive: false

        implicitWidth: cdRow.implicitWidth + 12
        implicitHeight: cdRow.implicitHeight + 6

        radius: height / 2
        color: cdMouse.containsMouse ? Qt.rgba(PowerTimer.mode === "reboot" ? 0.31 : 1, PowerTimer.mode === "reboot" ? 0.98 : 0.33, PowerTimer.mode === "reboot" ? 0.48 : 0.33, 0.16) : Qt.rgba(1, 1, 1, 0.14)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        // breathe when the action is under a minute away
        SequentialAnimation on opacity {
            running: PowerTimer.active && PowerTimer.remaining <= 60
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.45; duration: 500 }
            NumberAnimation { to: 1; duration: 500 }
        }

        content: RowLayout {
            id: cdRow

            spacing: 4

            Text {
                text: PowerTimer.mode === "reboot" ? "\uf021" : "\uf011"
                color: PowerTimer.mode === "reboot" ? "#50fa7b" : "#ff5555"
                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
            }

            Text {
                text: PowerTimer.formatTime(PowerTimer.remaining)
                color: "#f8f8f2"
                font { pixelSize: 10; bold: true; family: "ZedMono Nerd Font" }
            }
        }

        MouseArea {
            id: cdMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: PowerTimer.cancel()
        }
    }

    // coffee cup — appears right of quicksettings while caffeine mode is on
    Caffeine {}
}
