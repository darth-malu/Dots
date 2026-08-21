import QtQuick
import QtQuick.Layouts

Item {
    required property string icon
    required property color color
    required property string cmd
    property string label

    Layout.fillWidth: true
    Layout.preferredHeight: 40

    property real scaleVal: 1

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mouseArea.containsMouse ? Qt.rgba(parent.color.r, parent.color.g, parent.color.b, 0.12) : "transparent"
        scale: parent.scaleVal

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 1

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: parent.parent.icon
            color: mouseArea.containsMouse ? parent.parent.color : Qt.rgba(parent.parent.color.r, parent.parent.color.g, parent.parent.color.b, 0.6)
            font {
                pixelSize: 16
                family: "Symbols Nerd Font Mono"
            }
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: parent.parent.label
            color: mouseArea.containsMouse ? parent.parent.color : "#585b70"
            font {
                pixelSize: 8
                family: "Quicksand"
                bold: true
            }
            visible: parent.parent.label.length > 0
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: parent.scaleVal = 0.9
        onReleased: parent.scaleVal = 1
        onClicked: {
            root.showQsPopup = false;
            root.showPowerPopup = false;
            Quickshell.execDetached(["sh", "-c", parent.cmd]);
        }
    }

    Behavior on scaleVal {
        NumberAnimation {
            duration: 80
            easing.type: Easing.OutCubic
        }
    }
}
