import QtQuick
import QtQuick.Layouts
import qs.services
import Quickshell

// ── Brightness slider ──
RowLayout {
    id: root
    spacing: 10
    Layout.fillWidth: true
    visible: BatteryState.available
    property real brightness: 0
    property real maxBrightness: 100

    Text {
        text: "\uf185"
        color: "#f1fa8c"
        font {
            pixelSize: 14
            family: "Symbols Nerd Font Mono"
        }
    }

    Text {
        text: Math.round(root.brightness) + "%"
        color: "#f8f8f2"
        font {
            pixelSize: 10
            family: "ZedMono Nerd Font"
            bold: true
        }
        Layout.preferredWidth: 36
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 5

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 5
            radius: 2.5
            color: "#343746"

            Rectangle {
                width: parent.width * Math.min(root.brightness / 100, 1)
                height: parent.height
                radius: 2.5
                color: "#f1fa8c"

                Behavior on width {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            property bool dragging: false

            function setFromMouse(mx) {
                root.brightness = Math.max(0, Math.min(Math.round(mx / width * 100), 100));
                brightnessCommitTimer.restart();
            }

            onPressed: mouse => {
                dragging = true;
                setFromMouse(mouse.x);
            }
            onPositionChanged: mouse => {
                if (dragging)
                    setFromMouse(mouse.x);
            }
            onReleased: {
                dragging = false;
                brightnessCommitTimer.restart();
            }
        }
    }

    Timer {
        id: brightnessCommitTimer
        interval: 60
        running: false
        repeat: false
        onTriggered: Quickshell.execDetached(["sh", "-c", "brightnessctl set " + Math.round(root.brightness) + "%"])
    }
}
