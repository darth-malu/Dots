pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.customItems
import qs.services
import qs.bar
import qs.bar.quicksettings
import qs.bar.time

RowLayout {
    id: root

    // matches rightBlock's module gap in Bar.qml
    spacing: 8

    Layout.alignment: Qt.AlignVCenter

    required property var host

    // when true the clock is embedded in this row (bar default layout)
    property bool clockInside: false

    Loader {
        visible: active
        asynchronous: true
        active: true
        sourceComponent: connections
        Layout.alignment: Qt.AlignVCenter
    }

    Component {
        id: connections
        RowLayout {
            spacing: 4

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
        // standalone tray pill with a DISTINCT glass finish so it reads as
        // its own surface, separate from the bar slab and neighbouring
        // modules:
        //   transparent bar → brighter frosted glass + visible hairline
        //   solid / full bar → lifted slate pill, clearly not bar background
        BarBlock {
            id: traySlab

            interactive: false

            // REAL implicit size, not just Layout attached props — this
            // block lives inside a Loader, where attached Layout.* on the
            // delegate is inert; without these the pill collapses to 0×0
            implicitWidth: trayRow.implicitWidth
            // implicitHeight: Math.max(trayRow.implicitHeight, 22)
            implicitHeight: trayRow.implicitHeight + 1

            // hide completely until SNI items actually register
            // (Repeater.count is reliably notified, unlike list .values)
            visible: systemTrayRepeater.count > 0

            readonly property bool glassy: BarState.barMode === 0

            radius: height / 2
            color: glassy ? Qt.rgba(1, 1, 1, 0.16) : "#3b3f54"
            border.width: 1
            border.color: glassy ? Qt.rgba(0.74, 0.58, 0.98, 0.28) : Qt.rgba(0.74, 0.58, 0.98, 0.18)

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 160
                }
            }

            content: RowLayout {
                id: trayRow

                spacing: 6

                // horizontal pill padding lives inside the content row so
                // the slab's implicit width always covers it
                Item {
                    Layout.preferredWidth: 1
                }

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
                        implicitWidth: 13
                        implicitHeight: 13
                        color: "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 110
                            }
                        }

                        // gentle squish on press — tactile without being noisy
                        scale: delegateMa.pressed ? 0.86 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 90
                                easing.type: Easing.OutCubic
                            }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            source: parent.item.icon
                            implicitSize: 13
                            asynchronous: true
                            opacity: delegateMa.containsMouse || delegateMa.pressed ? 1 : 0.88

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 110
                                }
                            }
                        }

                        // ToolTip.visible: delegateMa.containsMouse && !menuAnchor.visible && delegate.tipText.length > 0
                        // ToolTip.delay: 450
                        // ToolTip.text: delegate.tipText

                        MouseArea {
                            id: delegateMa

                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: event => {
                                if (event.button == Qt.LeftButton) {
                                    try {
                                        delegate.item.activate();
                                    } catch (e) {}
                                } else if (event.button == Qt.RightButton) {
                                    if (delegate.hasMenu) {
                                        delegate.menuArmed = true;
                                        menuAnchor.open();
                                    } else {
                                        try {
                                            delegate.item.activate();
                                        } catch (e) {}
                                    }
                                } else if (event.button == Qt.MiddleButton) {
                                    try {
                                        delegate.item.secondaryActivate();
                                    } catch (e) {}
                                }
                            }
                        }

                        QsMenuAnchor {
                            id: menuAnchor
                            menu: delegate.menuArmed ? delegate.item.menu : null

                            anchor.window: delegate.QsWindow.window
                            // NOTE: binds to the  systemtrayItem that called the menu
                            anchor.adjustment: PopupAdjustment.Flip

                            anchor.onAnchoring: {
                                const window = delegate.QsWindow.window;
                                const widgetRect = window.contentItem.mapFromItem(delegate, 0, delegate.height, delegate.width, 0);

                                menuAnchor.anchor.rect = widgetRect;
                            }
                        }
                    }
                }

                // horizontal pill padding lives inside the content row so
                // the slab's implicit width always covers it
                Item {
                    Layout.preferredWidth: 1
                }
            }
        }
    }

    VolumePills {
        Layout.alignment: Qt.AlignVCenter
        host: root.host
        visible: MiscState.showVolumeOut || MiscState.showVolumeIn
    }

    // battery sits just left of the clock
    Battery {
        host: root.host
        Layout.alignment: Qt.AlignVCenter
    }

    // clock lives in this row, right where quicksettings used to sit
    ClockWidget {
        host: root.host
        visible: root.clockInside
        Layout.alignment: Qt.AlignVCenter
    }

    // ── standalone tray — its own group, directly left of quicksettings ──
    // never mixed into the connections cluster; emptiness is handled INSIDE
    // the block (visible: repeater.count > 0), because gating activation on
    // SystemTray.items.values races SNI's async registration and can latch
    // inactive forever
    Loader {
        visible: active
        asynchronous: true
        active: MiscState.toggleSysTray
        Layout.alignment: Qt.AlignVCenter

        sourceComponent: sysBlock
    }

    QuickSettings {
        host: root.host
        Layout.alignment: Qt.AlignVCenter
    }

    // live countdown pill while a reboot/shutdown timer is armed —
    // left-click cancels it
    BarBlock {
        visible: PowerTimer.active

        interactive: false

        implicitWidth: cdRow.implicitWidth + 12
        implicitHeight: cdRow.implicitHeight + 8

        radius: height / 2
        color: cdMouse.containsMouse ? Qt.rgba(PowerTimer.mode === "reboot" ? 0.31 : 1, PowerTimer.mode === "reboot" ? 0.98 : 0.33, PowerTimer.mode === "reboot" ? 0.48 : 0.33, 0.16) : Qt.rgba(1, 1, 1, 0.14)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        // breathe when the action is under a minute away
        SequentialAnimation on opacity {
            running: PowerTimer.active && PowerTimer.remaining <= 60
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation {
                to: 0.45
                duration: 500
            }
            NumberAnimation {
                to: 1
                duration: 500
            }
        }

        content: RowLayout {
            id: cdRow

            spacing: 4

            Text {
                text: PowerTimer.mode === "reboot" ? "\uf021" : "\uf011"
                color: PowerTimer.mode === "reboot" ? "#50fa7b" : "#ff5555"
                font {
                    pixelSize: 10
                    family: "Symbols Nerd Font Mono"
                }
            }

            Text {
                text: PowerTimer.formatTime(PowerTimer.remaining)
                color: "#f8f8f2"
                font {
                    pixelSize: 10
                    bold: true
                    family: "ZedMono Nerd Font"
                }
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
    Submap {}
}
