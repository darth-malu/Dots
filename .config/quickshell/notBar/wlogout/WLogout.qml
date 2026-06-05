import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    property color backgroundColor: "#e60c0c0c"
    property color buttonColor: "#1e1e2e"
    property color buttonHoverColor: "#cba6f7"
    property color buttonTextColor: "#cdd6f4"
    default property list<LogoutButton> buttons

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
                if (event.key == Qt.Key_Escape)
                    Qt.quit();
                else {
                    for (let i = 0; i < buttons.length; i++) {
                        let button = buttons[i];
                        if (event.key == button.keybind)
                            button.exec();
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
                        color: "#f38ba8"
                        font {
                            pixelSize: 32
                            family: "Symbols Nerd Font Mono"
                        }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 8
                    }

                    GridLayout {
                        columns: Math.min(buttons.length, 3)
                        columnSpacing: 16
                        rowSpacing: 16

                        Repeater {
                            model: buttons
                            delegate: Rectangle {
                                required property LogoutButton modelData

                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 100

                                radius: 12
                                color: ma.containsMouse ? buttonHoverColor : buttonColor
                                border.color: ma.containsMouse ? Qt.lighter(buttonHoverColor, 1.2) : "#313244"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Image {
                                        id: icon
                                        Layout.alignment: Qt.AlignHCenter
                                        source: `icons/${modelData.icon}.png`
                                        width: 36
                                        height: 36
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.text
                                        color: ma.containsMouse ? "#1e1e2e" : buttonTextColor
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
                                    onClicked: modelData.exec()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
