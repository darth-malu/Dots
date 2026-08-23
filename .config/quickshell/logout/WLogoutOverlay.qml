import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.services

Item {
    id: root

    property color backgroundColor: "#e60c0c0c"
    property color buttonColor: "#282a36"
    property color buttonHoverColor: "#bd93f9"
    property color buttonTextColor: "#f8f8f2"

    default property list<QtObject> _unused

    // timer duration slider — holds the LogoutButton being scheduled
    property var pickerButton: null

    function close() {
        root.pickerButton = null;
        MiscState.logoutOpen = false;
    }

    function fmtMin(m) {
        if (m < 60)
            return m + "m";
        const h = Math.floor(m / 60);
        const r = m % 60;
        return h + "h" + (r > 0 ? " " + r + "m" : "");
    }

    function schedule(mins) {
        const btn = root.pickerButton;
        if (!btn)
            return;
        const what = btn.timerCmd.indexOf("-r") >= 0 ? "Reboot" : "Shutdown";
        Quickshell.execDetached(["sh", "-c",
            `${btn.timerCmd} +${mins} && notify-send -a WLogout '${what} scheduled' 'in ${root.fmtMin(mins)}'` +
            ` || notify-send -u critical -a WLogout '${what} timer failed' 'shutdown rejected the request'`]);
        root.close();
    }

    function cancelPending() {
        Quickshell.execDetached(["sh", "-c",
            `shutdown -c && notify-send -a WLogout 'Timer cancelled' 'pending shutdown/reboot cleared'` +
            ` || notify-send -a WLogout 'Nothing to cancel' 'no pending timer'`]);
        root.close();
    }

    property list<LogoutButton> buttons: [lockBtn, exitBtn, restartTimerBtn, shutdownTimerBtn]

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

        color: "transparent"

        contentItem {
            focus: true
            Keys.onPressed: event => {
                if (event.key == Qt.Key_Escape) {
                    if (root.pickerButton)
                        root.pickerButton = null;
                    else
                        root.close();
                } else if ((event.key == Qt.Key_Return || event.key == Qt.Key_Enter) && root.pickerButton && sld.value > 0) {
                    // Enter confirms the slider value
                    root.schedule(sld.value);
                } else if (!root.pickerButton) {
                    for (let i = 0; i < buttons.length; i++) {
                        let button = buttons[i];
                        if (event.key == button.keybind) {
                            if (button.timerCmd.length > 0)
                                root.pickerButton = button;
                            else
                                button.exec();
                        }
                    }
                }
            }
        }

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        Rectangle {
            color: backgroundColor
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: ""
                        visible: root.pickerButton === null
                        color: "#ff5555"
                        font {
                            pixelSize: 32
                            family: "Symbols Nerd Font Mono"
                        }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 8
                    }

                    Grid {
                        visible: root.pickerButton === null
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 16
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: buttons
                            delegate: Rectangle {
                                required property LogoutButton modelData

                                width: 120
                                height: 100

                                radius: 12
                                color: ma.containsMouse ? buttonHoverColor : buttonColor
                                border.color: ma.containsMouse ? Qt.lighter(buttonHoverColor, 1.2) : "#343746"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon
                                        color: ma.containsMouse ? "#282a36" : buttonTextColor
                                        font {
                                            pixelSize: 28
                                            family: "Symbols Nerd Font Mono"
                                        }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.text
                                        color: ma.containsMouse ? "#282a36" : buttonTextColor
                                        font {
                                            pointSize: 12
                                            bold: true
                                            family: "Quicksand"
                                        }

                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }

                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.timerCmd.length > 0)
                                            root.pickerButton = modelData;
                                        else
                                            modelData.exec();
                                    }
                                }
                            }
                        }
                    }

                    // ─── timer duration picker — modern slider, 0 = off ───
                    ColumnLayout {
                        visible: root.pickerButton !== null
                        spacing: 14

                        // action icon + title
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.pickerButton ? root.pickerButton.icon : ""
                            color: "#bd93f9"
                            font {
                                pixelSize: 34
                                family: "Symbols Nerd Font Mono"
                            }
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.pickerButton ? root.pickerButton.text : ""
                            color: "#f8f8f2"
                            font {
                                pointSize: 16
                                bold: true
                                family: "Quicksand"
                            }
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // live readout
                        Text {
                            id: readout
                            property int mins: sld.value
                            Layout.alignment: Qt.AlignHCenter
                            text: mins === 0 ? "off" : root.fmtMin(mins)
                            color: mins === 0 ? "#6272a4" : "#bd93f9"
                            font {
                                pixelSize: 40
                                bold: true
                                family: "ZedMono Nerd Font"
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        Slider {
                            id: sld

                            from: 0
                            to: 240
                            stepSize: 5
                            value: 0

                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12

                            background: Rectangle {
                                implicitHeight: 24
                                color: "transparent"

                                // track + filled portion
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 6
                                    radius: 3
                                    color: "#343746"
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: sld.visualPosition * parent.width
                                    height: 6
                                    radius: 3
                                    color: "#bd93f9"
                                }

                                // minor ticks every 15 min (majors live under the labels)
                                Repeater {
                                    model: 15

                                    Rectangle {
                                        required property int index
                                        x: ((index + 1) / 16) * parent.width - 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 2
                                        height: 10
                                        radius: 1
                                        color: (index + 1) % 4 === 0 ? "#bd93f9" : "#44475a"
                                        opacity: (index + 1) % 4 === 0 ? 0.9 : 0.55
                                    }
                                }
                            }

                            handle: Rectangle {
                                x: sld.leftPadding + sld.visualPosition * (sld.availableWidth - width)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 18
                                radius: 9
                                color: sld.pressed ? "#ff79c6" : "#f8f8f2"
                                border.color: "#bd93f9"
                                border.width: 2

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }
                            }

                            Component.onCompleted: forceActiveFocus()
                        }

                        // scale labels
                        Item {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            implicitHeight: 14

                            Repeater {
                                model: ["0", "1h", "2h", "3h", "4h"]

                                Text {
                                    required property string modelData
                                    required property int index

                                    property real frac: index / 4

                                    x: index === 0 ? 0 : index === 4 ? parent.width - width : frac * parent.width - width / 2
                                    text: modelData
                                    color: Math.abs(sld.value - index * 60) < 1 ? "#bd93f9" : "#6272a4"
                                    font {
                                        pixelSize: 9
                                        bold: true
                                        family: "ZedMono Nerd Font"
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            Rectangle {
                                width: 72
                                height: 32
                                radius: 8
                                color: bkma.containsMouse ? "#44475a" : "transparent"
                                border.color: "#343746"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf060 back"
                                    color: bkma.containsMouse ? "#f8f8f2" : "#6272a4"
                                    font {
                                        pixelSize: 11
                                        family: "Symbols Nerd Font Mono"
                                    }
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: bkma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pickerButton = null
                                }
                            }

                            Rectangle {
                                width: 158
                                height: 32
                                radius: 8
                                color: cma.containsMouse ? "#ff5555" : "transparent"
                                border.color: cma.containsMouse ? "#ff5555" : "#343746"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf014 cancel pending"
                                    color: cma.containsMouse ? "#282a36" : "#6272a4"
                                    font {
                                        pixelSize: 11
                                        family: "Symbols Nerd Font Mono"
                                    }
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: cma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cancelPending()
                                }
                            }

                            Rectangle {
                                property bool ready: readout.mins > 0

                                width: 128
                                height: 36
                                radius: 8
                                opacity: ready ? 1 : 0.35
                                color: !ready ? "#21222c" : sma.containsMouse ? "#ff79c6" : buttonHoverColor
                                border.color: ready ? Qt.lighter(buttonHoverColor, 1.2) : "#343746"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf073 schedule"
                                    color: !readout.mins ? "#6272a4" : "#282a36"
                                    font {
                                        pixelSize: 11
                                        bold: true
                                        family: "Symbols Nerd Font Mono"
                                    }
                                }

                                MouseArea {
                                    id: sma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: readout.mins > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (readout.mins > 0)
                                            root.schedule(readout.mins);
                                    }
                                }

                                Behavior on border.color { ColorAnimation { duration: 120 } }
                            }
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
        text: "Lock"
        icon: "\uf023"
    }

    LogoutButton {
        id: exitBtn
        command: "loginctl terminate-user $USER"
        keybind: Qt.Key_E
        text: "Logout"
        icon: "\uf08b"
    }

    LogoutButton {
        id: restartTimerBtn
        keybind: Qt.Key_T
        text: "Restart Timer"
        icon: "\uf021"
        timerCmd: "shutdown -r"
    }

    LogoutButton {
        id: shutdownTimerBtn
        keybind: Qt.Key_Y
        text: "Shutdown Timer"
        icon: "\uf011"
        timerCmd: "shutdown -h"
    }
}
