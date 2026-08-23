import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.services

// Fullscreen logout / session overlay.
// Left-click fires the action immediately · right-click on restart /
// shutdown opens an inline delay slider · any pending PowerTimer
// countdown is mirrored here live and can be cancelled.
Item {
    id: root

    // 0 = hidden · 2 = restart scheduler · 3 = shutdown scheduler
    // (values mirror the button indices in `buttons` below)
    property int timerPicker: 0

    // palette
    readonly property color fg: "#f8f8f2"
    readonly property color dim: "#b8bfcb"
    readonly property color faint: "#6272a4"
    readonly property color line: "#313244"
    readonly property color cardBg: Qt.rgba(24 / 255, 24 / 255, 37 / 255, 0.92)

    default property list<QtObject> _unused

    function close() {
        MiscState.logoutOpen = false;
        timerPicker = 0;
    }

    property list<LogoutButton> buttons: [lockBtn, exitBtn, rebootBtn, shutdownBtn]

    function fmtMin(mins) {
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        if (h > 0 && m > 0)
            return h + "h " + m + "m";
        if (h > 0)
            return h + "h";
        return mins + "m";
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: w

            required property var modelData
            screen: modelData
            visible: MiscState.logoutOpen

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // actions fire without going through close(), so reset here too
            onVisibleChanged: {
                if (!visible)
                    root.timerPicker = 0;
            }

            color: "transparent"

            contentItem {
                focus: true
                Keys.onPressed: event => {
                    if (event.key == Qt.Key_Escape)
                        root.close();
                    else
                        for (let i = 0; i < buttons.length; i++)
                            if (event.key == buttons[i].keybind)
                                buttons[i].exec();
                }
            }

            anchors {
                top: true
                left: true
                bottom: true
                right: true
            }

            // ── backdrop — soft vertical dim ──
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#ee101018"
                    }
                    GradientStop {
                        position: 1
                        color: "#f5181825"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 28

                        // ═══ main card ═══
                        Rectangle {
                            id: sheet

                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 620
                            implicitHeight: innerCol.implicitHeight + 72
                            radius: 26
                            color: root.cardBg
                            border.width: 1
                            border.color: root.line

                            // swallows clicks so the backdrop-close
                            // doesn't fire from dead space inside the card
                            MouseArea {
                                anchors.fill: parent
                            }

                            ColumnLayout {
                                id: innerCol

                                anchors.centerIn: parent
                                width: parent.width - 72
                                spacing: 30

                                // ── session title ──
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 6

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: QuickState.hostName
                                        color: root.fg
                                        font {
                                            pixelSize: 21
                                            bold: true
                                            family: "Quicksand"
                                            letterSpacing: 3
                                        }
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: 56
                                        implicitHeight: 2
                                        radius: 1
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop {
                                                position: 0
                                                color: "transparent"
                                            }
                                            GradientStop {
                                                position: 0.5
                                                color: Qt.rgba(0.74, 0.58, 0.98, 0.7)
                                            }
                                            GradientStop {
                                                position: 1
                                                color: "transparent"
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "end session?"
                                        color: root.faint
                                        font {
                                            pixelSize: 10
                                            bold: true
                                            family: "Quicksand"
                                            letterSpacing: 5
                                            capitalization: Font.AllUppercase
                                        }
                                    }
                                }

                                // ── action row ──
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 34

                                    Repeater {
                                        model: root.buttons

                                        delegate: Item {
                                            id: actionBtn

                                            required property LogoutButton modelData
                                            required property int index

                                            // restart / shutdown carry schedulers
                                            readonly property bool schedulable: index >= 2
                                            // matching timer currently armed
                                            readonly property bool armed: schedulable
                                                && ((index === 2 && PowerTimer.mode === "reboot")
                                                    || (index === 3 && PowerTimer.mode === "poweroff"))
                                            // this button's scheduler panel is open
                                            readonly property bool picked: root.timerPicker === index

                                            implicitWidth: btnCol.implicitWidth
                                            implicitHeight: btnCol.implicitHeight

                                            ColumnLayout {
                                                id: btnCol
                                                spacing: 10

                                                Item {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.preferredWidth: circle.width + 16
                                                    Layout.preferredHeight: circle.height + 16

                                                    // soft halo behind the circle on hover / while armed
                                                    Rectangle {
                                                        anchors.centerIn: circle
                                                        width: circle.width * 1.22
                                                        height: width
                                                        radius: width / 2
                                                        color: Qt.rgba(actionBtn.modelData.accent.r, actionBtn.modelData.accent.g, actionBtn.modelData.accent.b, actionBtn.armed ? 0.14 : 0.0)
                                                        opacity: ma.containsMouse || actionBtn.armed ? 1 : 0
                                                        visible: opacity > 0

                                                        Behavior on opacity {
                                                            NumberAnimation { duration: 180 }
                                                        }
                                                    }

                                                    Rectangle {
                                                        id: circle

                                                        anchors.centerIn: parent
                                                        width: 88
                                                        height: 88
                                                        radius: height / 2
                                                        color: ma.containsMouse ? Qt.rgba(actionBtn.modelData.accent.r, actionBtn.modelData.accent.g, actionBtn.modelData.accent.b, 0.16)
                                                            : actionBtn.armed ? Qt.rgba(actionBtn.modelData.accent.r, actionBtn.modelData.accent.g, actionBtn.modelData.accent.b, 0.10)
                                                            : "#21222c"
                                                        border.width: ma.containsMouse ? 1.5 : actionBtn.armed || actionBtn.picked ? 1.5 : 1
                                                        border.color: ma.containsMouse || actionBtn.armed || actionBtn.picked ? actionBtn.modelData.accent : root.line

                                                        Behavior on color { ColorAnimation { duration: 140 } }
                                                        Behavior on border.color { ColorAnimation { duration: 140 } }
                                                        Behavior on scale {
                                                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                                        }

                                                        scale: ma.pressed ? 0.94 : ma.containsMouse ? 1.06 : 1

                                                        SequentialAnimation on opacity {
                                                            running: actionBtn.armed
                                                            loops: Animation.Infinite
                                                            alwaysRunToEnd: true
                                                            NumberAnimation { to: 0.55; duration: 700 }
                                                            NumberAnimation { to: 1; duration: 700 }
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: actionBtn.modelData.icon
                                                            color: ma.containsMouse || actionBtn.armed ? actionBtn.modelData.accent : root.dim
                                                            font {
                                                                pixelSize: 30
                                                                family: "Symbols Nerd Font Mono"
                                                            }

                                                            Behavior on color { ColorAnimation { duration: 140 } }
                                                        }

                                                        // dot marking an armed timer
                                                        Rectangle {
                                                            anchors.top: parent.top
                                                            anchors.right: parent.right
                                                            anchors.margins: 10
                                                            width: 9
                                                            height: 9
                                                            radius: 4.5
                                                            visible: actionBtn.armed
                                                            color: actionBtn.modelData.accent
                                                            border.width: 2
                                                            border.color: "#181825"
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: ma
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                        onClicked: mouse => {
                                                            if (mouse.button === Qt.RightButton && actionBtn.schedulable) {
                                                                root.timerPicker = actionBtn.picked ? 0 : actionBtn.index;
                                                                return;
                                                            }
                                                            if (mouse.button === Qt.LeftButton)
                                                                actionBtn.modelData.exec();
                                                        }
                                                    }
                                                }

                                                // label + keycap hint
                                                ColumnLayout {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    spacing: 5

                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: actionBtn.modelData.text
                                                        color: ma.containsMouse || actionBtn.armed ? root.fg : root.dim
                                                        font {
                                                            pixelSize: 11
                                                            bold: true
                                                            family: "Quicksand"
                                                            letterSpacing: 1
                                                        }

                                                        Behavior on color { ColorAnimation { duration: 140 } }
                                                    }

                                                    Rectangle {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        implicitWidth: keyTxt.implicitWidth + 12
                                                        implicitHeight: 17
                                                        radius: 5
                                                        color: ma.containsMouse ? Qt.rgba(actionBtn.modelData.accent.r, actionBtn.modelData.accent.g, actionBtn.modelData.accent.b, 0.15) : "#262636"
                                                        border.width: 1
                                                        border.color: ma.containsMouse ? Qt.rgba(actionBtn.modelData.accent.r, actionBtn.modelData.accent.g, actionBtn.modelData.accent.b, 0.45) : root.line

                                                        Behavior on color { ColorAnimation { duration: 140 } }
                                                        Behavior on border.color { ColorAnimation { duration: 140 } }

                                                        Text {
                                                            id: keyTxt
                                                            anchors.centerIn: parent
                                                            text: actionBtn.modelData.keybindChar
                                                            color: ma.containsMouse ? actionBtn.modelData.accent : root.faint
                                                            font {
                                                                pixelSize: 9
                                                                bold: true
                                                                family: "ZedMono Nerd Font"
                                                            }

                                                            Behavior on color { ColorAnimation { duration: 140 } }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ═══ scheduler / live countdown ═══
                                ColumnLayout {
                                    id: timerZone

                                    readonly property bool isReboot: root.timerPicker === 2
                                    readonly property string modeName: root.timerPicker === 2 ? "Restart" : "Shutdown"
                                    readonly property color tint: isReboot ? "#50fa7b" : "#ff5555"
                                    // selection, minutes — armed on release
                                    property int selMin: 15

                                    visible: root.timerPicker !== 0 || PowerTimer.active
                                    Layout.fillWidth: true
                                    spacing: 10

                                    // ── delay slider ──
                                    ColumnLayout {
                                        visible: root.timerPicker !== 0
                                        Layout.fillWidth: true
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                text: timerZone.modeName + " after:"
                                                color: timerZone.tint
                                                font {
                                                    pixelSize: 10
                                                    bold: true
                                                    family: "Quicksand"
                                                    letterSpacing: 2
                                                    capitalization: Font.AllUppercase
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                visible: delaySlider.pressed
                                                text: root.fmtMin(timerZone.selMin)
                                                color: timerZone.tint
                                                font {
                                                    pixelSize: 14
                                                    bold: true
                                                    family: "ZedMono Nerd Font"
                                                }
                                            }
                                        }

                                        Slider {
                                            id: delaySlider

                                            from: 5
                                            to: 240
                                            stepSize: 5
                                            value: timerZone.selMin

                                            Layout.fillWidth: true
                                            Layout.leftMargin: 4
                                            Layout.rightMargin: 4

                                            background: Rectangle {
                                                implicitHeight: 18
                                                color: "transparent"

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width
                                                    height: 6
                                                    radius: 3
                                                    color: "#343746"
                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: delaySlider.visualPosition * parent.width
                                                    height: 6
                                                    radius: 3
                                                    color: timerZone.tint
                                                }
                                            }

                                            handle: Rectangle {
                                                x: delaySlider.leftPadding + delaySlider.visualPosition * (delaySlider.availableWidth - width)
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: delaySlider.pressed ? root.fg : "#282a36"
                                                border.color: timerZone.tint
                                                border.width: 2

                                                Behavior on color {
                                                    ColorAnimation { duration: 100 }
                                                }
                                            }

                                            onMoved: timerZone.selMin = value
                                            onPressedChanged: {
                                                if (!pressed) {
                                                    timerZone.selMin = value;
                                                    if (root.timerPicker === 2)
                                                        PowerTimer.scheduleReboot(value * 60);
                                                    else
                                                        PowerTimer.schedulePoweroff(value * 60);
                                                }
                                            }
                                        }

                                        // scale hints at their real positions
                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: 12

                                            Repeater {
                                                model: [
                                                    { min: 30, label: "30m" },
                                                    { min: 60, label: "1h" },
                                                    { min: 120, label: "2h" },
                                                    { min: 180, label: "3h" }
                                                ]

                                                Text {
                                                    required property var modelData

                                                    x: 4 + (parent.width - 8) * ((modelData.min - 5) / 235) - width / 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.label
                                                    color: root.faint
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
                                                color: root.faint
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
                                                color: root.faint
                                                font {
                                                    pixelSize: 8
                                                    bold: true
                                                    family: "ZedMono Nerd Font"
                                                }
                                            }
                                        }
                                    }

                                    // ── live countdown banner ──
                                    Rectangle {
                                        id: liveBanner

                                        visible: PowerTimer.active
                                        readonly property color tint: PowerTimer.mode === "reboot" ? "#50fa7b" : "#ff5555"

                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: liveRow.implicitWidth + 40
                                        implicitHeight: liveRow.implicitHeight + 20
                                        radius: height / 2
                                        color: Qt.rgba(tint.r, tint.g, tint.b, 0.10)
                                        border.width: 1
                                        border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.45)

                                        RowLayout {
                                            id: liveRow
                                            anchors.centerIn: parent
                                            spacing: 12

                                            Text {
                                                text: PowerTimer.mode === "reboot" ? "\uf021" : "\uf011"
                                                color: liveBanner.tint
                                                font { pixelSize: 15; family: "Symbols Nerd Font Mono" }
                                            }

                                            Text {
                                                text: (PowerTimer.mode === "reboot" ? "Restarting" : "Shutting down") + " in "
                                                color: root.dim
                                                font { pixelSize: 11; bold: true; family: "Quicksand" }
                                            }

                                            Text {
                                                readonly property color tint: PowerTimer.mode === "reboot" ? "#50fa7b" : "#ff5555"

                                                text: PowerTimer.formatTime(PowerTimer.remaining)
                                                color: tint
                                                font {
                                                    pixelSize: 16
                                                    bold: true
                                                    family: "ZedMono Nerd Font"
                                                }
                                            }

                                            Rectangle {
                                                implicitWidth: cancelTxt.implicitWidth + 20
                                                implicitHeight: 24
                                                radius: 12
                                                color: cancelMa.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.18) : "#343746"
                                                border.width: 1
                                                border.color: cancelMa.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.5) : "transparent"

                                                Behavior on color { ColorAnimation { duration: 120 } }
                                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                                Text {
                                                    id: cancelTxt
                                                    anchors.centerIn: parent
                                                    text: "\uf00d  cancel"
                                                    color: cancelMa.containsMouse ? "#ff5555" : root.dim
                                                    font { pixelSize: 9; bold: true; family: "Symbols Nerd Font Mono, Quicksand" }
                                                }

                                                MouseArea {
                                                    id: cancelMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: PowerTimer.cancel()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── footer hint ──
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "click  run    ·    right-click restart / shutdown to schedule    ·    esc  dismiss"
                            color: Qt.rgba(0.38, 0.42, 0.51, 0.85)
                            font {
                                pixelSize: 9
                                family: "ZedMono Nerd Font"
                                letterSpacing: 1
                            }
                        }
                    }
                }
            }
        }
    }

    LogoutButton {
        id: lockBtn
        command: "loginctl lock-session"
        keybind: Qt.Key_L
        keybindChar: "L"
        text: "Lock"
        icon: "\uf023"
        accent: "#bd93f9"
    }

    LogoutButton {
        id: exitBtn
        command: "loginctl terminate-user $USER"
        keybind: Qt.Key_E
        keybindChar: "E"
        text: "Logout"
        icon: "\uf08b"
        accent: "#ff79c6"
    }

    LogoutButton {
        id: rebootBtn
        command: "systemctl reboot"
        keybind: Qt.Key_R
        keybindChar: "R"
        text: "Restart"
        icon: "\uf021"
        accent: "#50fa7b"
    }

    LogoutButton {
        id: shutdownBtn
        command: "systemctl poweroff"
        keybind: Qt.Key_S
        keybindChar: "S"
        text: "Shutdown"
        icon: "\uf011"
        accent: "#ff5555"
    }
}
