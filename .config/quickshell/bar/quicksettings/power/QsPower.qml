import QtQuick
import QtQuick.Layouts

Item {
    id: btn

    required property string icon
    required property color color
    required property string cmd
    property string label

    // full accent color while a matching power timer is pending
    property bool highlighted: false
    // emitted on every click; empty cmd keeps the menus open instead of running a command
    signal activated

    Layout.fillWidth: true
    Layout.preferredHeight: 46

    property real scaleVal: 1

    Rectangle {
        id: powerBtnBg

        anchors.fill: parent
        anchors.margins: 2
        radius: 12
        color: mouseArea.containsMouse ? Qt.rgba(parent.color.r, parent.color.g, parent.color.b, 0.16) : parent.highlighted ? Qt.rgba(parent.color.r, parent.color.g, parent.color.b, 0.12) : Qt.rgba(parent.color.r, parent.color.g, parent.color.b, 0.05)
        scale: parent.scaleVal

        // thin accent ring on hover / while a matching timer is pending
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: mouseArea.containsMouse || parent.parent.highlighted ? 1 : 0
            border.color: Qt.rgba(parent.parent.color.r, parent.parent.color.g, parent.parent.color.b, 0.35)
        }

        // gentle breathing while a matching timer is pending
        SequentialAnimation on opacity {
            running: powerBtnBg.highlighted
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation {
                to: 0.35
                duration: 650
            }
            NumberAnimation {
                to: 1
                duration: 650
            }
        }

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
            color: parent.parent.highlighted || mouseArea.containsMouse ? parent.parent.color : Qt.rgba(parent.parent.color.r, parent.parent.color.g, parent.parent.color.b, 0.75)
            font {
                pixelSize: 19
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
            color: parent.parent.highlighted || mouseArea.containsMouse ? parent.parent.color : "#b8bfcb"
            font {
                pixelSize: 9
                family: "Quicksand"
                bold: true
                letterSpacing: 0.5
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
            if (btn.cmd.length > 0) {
                root.showQsPopup = false;
                root.showPowerPopup = false;
                Quickshell.execDetached(["sh", "-c", btn.cmd]);
            }
            btn.activated();
        }
    }

    Behavior on scaleVal {
        NumberAnimation {
            duration: 80
            easing.type: Easing.OutCubic
        }
    }
}
