import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    property color backgroundColor: "#e60c0c0c"
    property color buttonColor: "#282a36"
    property color buttonHoverColor: "#bd93f9"
    property color buttonTextColor: "#f8f8f2"
    default property list<LogoutButton> buttons

    // timer duration picker — holds the LogoutButton whose presets are shown
    property var pickerButton: null

    function fmtMin(m) {
        return m >= 60 ? (m / 60) + "h" : m + "m";
    }

    function schedule(mins) {
        const btn = root.pickerButton;
        if (!btn)
            return;
        const what = btn.timerCmd.indexOf("-r") >= 0 ? "Reboot" : "Shutdown";
        Quickshell.execDetached(["sh", "-c",
            `${btn.timerCmd} +${mins} && notify-send -a WLogout '${what} scheduled' 'in ${root.fmtMin(mins)}'` +
            ` || notify-send -u critical -a WLogout '${what} timer failed' 'shutdown rejected the request'`]);
        Qt.quit();
    }

    function cancelPending() {
        Quickshell.execDetached(["sh", "-c",
            `shutdown -c && notify-send -a WLogout 'Timer cancelled' 'pending shutdown/reboot cleared'` +
            ` || notify-send -a WLogout 'Nothing to cancel' 'no pending timer'`]);
        Qt.quit();
    }

    model: Quickshell.screens

    PanelWindow {
        id: w

        property var modelData
        screen: modelData

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
                        Qt.quit();
                } else if (!root.pickerButton) {
                    for (let i = 0; i < buttons.length; i++) {
                        let button = buttons[i];
                        if (event.key == button.keybind) {
                            if (button.presets !== null)
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
                onClicked: Qt.quit()

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: ""
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
                        columns: Math.min(buttons.length, 3)
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
                                        if (modelData.presets !== null)
                                            root.pickerButton = modelData;
                                        else
                                            modelData.exec();
                                    }
                                }
                            }
                        }
                    }

                    // ─── timer duration picker ───
                    ColumnLayout {
                        visible: root.pickerButton !== null
                        spacing: 14

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.pickerButton ? root.pickerButton.text : ""
                            color: "#bd93f9"
                            font {
                                pointSize: 16
                                bold: true
                                family: "Quicksand"
                            }
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Grid {
                            columns: 4
                            columnSpacing: 12
                            rowSpacing: 12
                            Layout.alignment: Qt.AlignHCenter

                            Repeater {
                                model: root.pickerButton ? root.pickerButton.presets : []

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 88
                                    height: 44
                                    radius: 10
                                    color: pma.containsMouse ? buttonHoverColor : buttonColor
                                    border.color: pma.containsMouse ? Qt.lighter(buttonHoverColor, 1.2) : "#343746"
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.fmtMin(modelData)
                                        color: pma.containsMouse ? "#282a36" : buttonTextColor
                                        font {
                                            pointSize: 11
                                            bold: true
                                            family: "Quicksand"
                                        }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    MouseArea {
                                        id: pma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.schedule(modelData)
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
                        }
                    }
                }
            }
        }
    }
}
