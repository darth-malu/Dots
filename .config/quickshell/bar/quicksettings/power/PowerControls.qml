pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.customItems
import qs.services

// power menu card + reboot/shutdown timer card — extracted from
// QuickSettings for easier management
ColumnLayout {
    id: pc

    // live state owned by QuickSettings root
    required property bool showPowerPopup
    required property int timerPicker

    // closing the whole quicksettings popup when a command fires
    signal closeRequested()
    // selecting a timer mode (0=none 1=reboot 2=shutdown)
    signal timerPicked(int mode)

    component TimerChip: Rectangle {
        id: chip

        property string txt
        property bool danger: false
        signal picked

        Layout.fillWidth: true
        implicitHeight: 24
        radius: 6
        color: {
            if (!mouse.containsMouse)
                return "#343746";
            return danger ? Qt.rgba(1, 0.33, 0.33, 0.15) : Qt.rgba(0.74, 0.58, 0.98, 0.15);
        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            anchors.centerIn: parent
            text: chip.txt
            color: mouse.containsMouse ? (chip.danger ? "#ff5555" : "#bd93f9") : "#b8bfcb"
            font {
                pixelSize: 9
                bold: true
                family: "Quicksand"
                letterSpacing: 1
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.picked()
        }
    }

    spacing: 8
                    Card {
                        title: ""
                        icon: ""
                        visible: pc.showPowerPopup
                        Layout.bottomMargin: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Layout.preferredHeight: 42

                            QsPower {
                                icon: ""
                                color: "#bd93f9"
                                label: "Lock"
                                cmd: "hyprlock"
                            }
                            QsPower {
                                icon: ""
                                color: "#50fa7b"
                                label: "Reboot"
                                highlighted: PowerTimer.mode === "reboot"
                                // left-click runs it now, right-click opens the timer slider
                                cmd: "systemctl reboot"
                                onActivated: pc.closeRequested()
                                onTimerRequested: pc.timerPicked(pc.timerPicker === 1 ? 0 : 1)
                            }
                            QsPower {
                                icon: "\uf011"
                                color: "#ff5555"
                                label: "Shutdown"
                                highlighted: PowerTimer.mode === "poweroff"
                                cmd: "systemctl poweroff"
                                onActivated: pc.closeRequested()
                                onTimerRequested: pc.timerPicked(pc.timerPicker === 2 ? 0 : 2)
                            }
                            QsPower {
                                icon: "\uf08b"
                                color: "#bd93f9"
                                label: "Exit"
                                cmd: "loginctl terminate-user $USER"
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "right-click restart / shutdown to schedule"
                            color: "#6272a4"
                            font {
                                pixelSize: 8
                                family: "Quicksand"
                                letterSpacing: 0.5
                            }
                        }
                    }
                    Card {
                        id: timerCard

                        title: ""
                        icon: ""
                        visible: pc.timerPicker !== 0
                        Layout.bottomMargin: 8
                        cardPadding: 10

                        readonly property bool isReboot: pc.timerPicker === 1
                        readonly property string modeName: isReboot ? "Reboot" : "Shutdown"
                        // a matching timer is armed; menu stays open as live confirmation
                        readonly property bool live: PowerTimer.active && PowerTimer.mode === (isReboot ? "reboot" : "poweroff")

                        // slider selection, minutes — committed on release
                        property int selMin: 15

                        function fmtMin(mins) {
                            const h = Math.floor(mins / 60);
                            const m = mins % 60;
                            if (h > 0 && m > 0)
                                return h + "h " + m + "m";
                            if (h > 0)
                                return h + "h";
                            return mins + "m";
                        }

                        function pick(minutes) {
                            if (isReboot)
                                PowerTimer.scheduleReboot(minutes * 60);
                            else
                                PowerTimer.schedulePoweroff(minutes * 60);
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // ── prompt / live countdown ──
                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: timerCard.live ? timerCard.modeName + " in " + PowerTimer.formatTime(PowerTimer.remaining) : timerCard.modeName + " after:"
                                    color: timerCard.live ? (timerCard.isReboot ? "#50fa7b" : "#ff5555") : "#6272a4"
                                    font {
                                        pixelSize: 9
                                        bold: true
                                        family: "Quicksand"
                                        letterSpacing: 1
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: !timerCard.live && timerSlider.pressed
                                    text: timerCard.fmtMin(timerCard.selMin)
                                    color: timerCard.isReboot ? "#50fa7b" : "#ff5555"
                                    font {
                                        pixelSize: 12
                                        bold: true
                                        family: "ZedMono Nerd Font"
                                    }
                                }
                            }

                            // ── delay slider — release to arm the timer ──
                            Slider {
                                id: timerSlider

                                from: 5
                                to: 240
                                stepSize: 5
                                value: timerCard.selMin

                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Layout.rightMargin: 4

                                background: Rectangle {
                                    implicitHeight: 18
                                    color: "transparent"

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 5
                                        radius: 2.5
                                        color: "#343746"
                                    }

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: timerSlider.visualPosition * parent.width
                                        height: 5
                                        radius: 2.5
                                        readonly property color tint: timerCard.isReboot ? "#50fa7b" : "#ff79c6"
                                        color: Qt.rgba(tint.r, tint.g, tint.b, 0.4)

                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 2.5
                                            radius: 1.25
                                            height: parent.height
                                            color: parent.tint
                                        }
                                    }
                                }

                                handle: Rectangle {
                                    x: timerSlider.leftPadding + timerSlider.visualPosition * (timerSlider.availableWidth - width)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    radius: 7
                                    readonly property color knobTint: timerCard.isReboot ? "#50fa7b" : "#ff79c6"
                                    color: knobTint
                                    border.color: Qt.rgba(knobTint.r, knobTint.g, knobTint.b, 0.4)
                                    border.width: 1

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 100
                                        }
                                    }
                                }

                                onMoved: timerCard.selMin = value
                                onPressedChanged: {
                                    if (!pressed) {
                                        timerCard.selMin = value;
                                        timerCard.pick(value);
                                    }
                                }
                            }

                            // ── scale hints at their real positions ──
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 11

                                Repeater {
                                    model: [
                                        {
                                            min: 30,
                                            label: "30m"
                                        },
                                        {
                                            min: 60,
                                            label: "1h"
                                        },
                                        {
                                            min: 120,
                                            label: "2h"
                                        },
                                        {
                                            min: 180,
                                            label: "3h"
                                        }
                                    ]

                                    Text {
                                        required property var modelData

                                        x: {
                                            const frac = (modelData.min - timerSlider.from) / (timerSlider.to - timerSlider.from);
                                            return 4 + (parent.width - 8) * frac - width / 2;
                                        }
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        color: "#6272a4"
                                        font {
                                            pixelSize: 8
                                            bold: true
                                            family: "ZedMono Nerd Font"
                                        }
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "5m"
                                    color: "#6272a4"
                                    font {
                                        pixelSize: 8
                                        bold: true
                                        family: "ZedMono Nerd Font"
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "4h"
                                    color: "#6272a4"
                                    font {
                                        pixelSize: 8
                                        bold: true
                                        family: "ZedMono Nerd Font"
                                    }
                                }
                            }

                            // ── cancel while a matching timer is armed ──
                            TimerChip {
                                visible: timerCard.live
                                txt: "cancel " + (PowerTimer.mode === "reboot" ? "reboot" : "shutdown") + " · " + PowerTimer.formatTime(PowerTimer.remaining)
                                danger: true
                                onPicked: PowerTimer.cancel()
                            }
                        }
                    }
}
