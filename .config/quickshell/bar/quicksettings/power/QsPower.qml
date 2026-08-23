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
    Layout.preferredHeight: 40

    property real scaleVal: 1

    Rectangle {
        id: powerBtnBg

        anchors.fill: parent
        radius: 8
        color: mouseArea.containsMouse ? Qt.rgba(parent.color.r, parent.color.g, parent.color.b, 0.12) : parent.highlighted ? Qt.rgba(parent.color.r, parent.color.g, parent.color.b, 0.10) : "transparent"
        scale: parent.scaleVal

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
            color: parent.parent.highlighted || mouseArea.containsMouse ? parent.parent.color : Qt.rgba(parent.parent.color.r, parent.parent.color.g, parent.parent.color.b, 0.6)
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
            color: parent.parent.highlighted || mouseArea.containsMouse ? parent.parent.color : "#6272a4"
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
