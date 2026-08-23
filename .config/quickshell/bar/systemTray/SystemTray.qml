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

        // breathing room between the tray slab and the bar edges
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        Layout.alignment: Qt.AlignVCenter

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
        // classic tray row inside one themed pill — each item keeps its own
        // hover tint; the pill adapts to the bar style setting:
        //   transparent bar → frosted glass tint
        //   solid / full bar → dark slab, distinct from the bar itself
        BarBlock {
            id: traySlab

            interactive: false

            Layout.preferredWidth: trayRow.implicitWidth + 14
            Layout.preferredHeight: trayRow.implicitHeight + 8

            readonly property bool glassy: BarState.barMode === 0

            radius: height / 2
            color: glassy ? Qt.rgba(1, 1, 1, 0.14) : "#313244"
            border.width: 1
            border.color: glassy ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.07)

            Behavior on color {
                ColorAnimation { duration: 160 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 160 }
            }

            content: RowLayout {
                id: trayRow

                spacing: 3

                Repeater {
                    id: systemTrayRepeater
                    model: SystemTray.items

                    delegate: Rectangle {
                        id: delegate

                        required property SystemTrayItem modelData

                        readonly property var item: modelData
                        readonly property bool hasMenu: item?.hasMenu ?? false
                        // menu only opens while this flag is armed — a stale
                        // QsMenuAnchor grabbing focus was closing it instantly
                        property bool menuArmed: false
                        onHasMenuChanged: if (!hasMenu)
                            menuArmed = false

                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 24
                        implicitHeight: 22
                        radius: 6
                        color: delegateMa.pressed ? Qt.rgba(0.741, 0.576, 0.976, 0.35)
                            : delegateMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16)
                            : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 110 }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            source: parent.item.icon
                            implicitSize: 13
                            asynchronous: true
                        }

                        MouseArea {
                            id: delegateMa

                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: event => {
                                if (event.button == Qt.LeftButton) {
                                    try { delegate.item.activate(); } catch (e) {}
                                } else if (event.button == Qt.RightButton) {
                                    if (delegate.hasMenu) {
                                        delegate.menuArmed = true;
                                        menuAnchor.open();
                                    } else {
                                        try { delegate.item.activate(); } catch (e) {}
                                    }
                                } else if (event.button == Qt.MiddleButton) {
                                    try { delegate.item.secondaryActivate(); } catch (e) {}
                                }
                            }
                        }

                        QsMenuAnchor {
                            id: menuAnchor
                            menu: delegate.menuArmed ? delegate.item.menu : null

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

    VolumePills {
        host: root.host
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
