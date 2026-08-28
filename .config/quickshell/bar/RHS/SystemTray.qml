pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.customItems
import qs.services
import qs.themes
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
        // standalone tray pill — boxy or glass depending on toggle
        BarBlock {
            id: traySlab

            interactive: false

            implicitWidth: traySlab.content ? traySlab.content.implicitWidth : 0
            implicitHeight: traySlab.content ? traySlab.content.implicitHeight + 1 : 0

            visible: traySlab.content ? traySlab.content.trayCount > 0 : false

            readonly property bool boxy: MiscState.boxyTheme
            readonly property bool solo: traySlab.content ? traySlab.content.singleItem : false

            radius: boxy ? Themes.boxyRadius : height / 2
            color: solo ? "transparent" : (boxy ? Themes.boxyActiveBg : (BarState.barMode === 0 ? Qt.rgba(1, 1, 1, 0.16) : "#3b3f54"))
            border.width: solo ? 0 : 1
            border.color: solo ? "transparent" : (boxy ? Themes.boxyActiveBorder : (BarState.barMode === 0 ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.28) : Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.18)))

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

            content: Tray {}
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
        id: powerPill

        visible: PowerTimer.active

        interactive: false

        // mode accent — green for reboot, red for shutdown
        readonly property color accent: PowerTimer.mode === "reboot" ? "#50fa7b" : "#ff5555"

        implicitWidth: cdRow.implicitWidth + 12
        implicitHeight: cdRow.implicitHeight + 8

        radius: height / 2
        color: cdMouse.containsMouse ? Qt.rgba(powerPill.accent.r, powerPill.accent.g, powerPill.accent.b, 0.30) : Qt.rgba(powerPill.accent.r, powerPill.accent.g, powerPill.accent.b, 0.17)
        border.width: 1
        border.color: Qt.rgba(powerPill.accent.r, powerPill.accent.g, powerPill.accent.b, cdMouse.containsMouse ? 0.9 : 0.55)

        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }

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
                color: powerPill.accent
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
