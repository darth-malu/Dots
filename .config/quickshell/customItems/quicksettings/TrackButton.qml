import QtQuick

Item {
    property string text
    property color accentColor: "#cba6f7"
    property bool active: false
    property bool flat: false
    signal clicked

    implicitWidth: 28
    implicitHeight: 28

    property real scaleVal: 1.0
    Behavior on scaleVal {
        NumberAnimation {
            duration: 80
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        visible: !parent.flat
        color: mouseArea.containsMouse ? Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.22) : parent.active ? Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.15) : Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.06)
        scale: parent.scaleVal
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "transparent"
        border {
            width: (mouseArea.containsMouse || parent.active) && !parent.flat ? 1 : 0
            color: Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.3)
        }
        Behavior on border.width {
            NumberAnimation {
                duration: 80
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: parent.text
        color: mouseArea.containsMouse ? parent.accentColor : (parent.active ? parent.accentColor : Qt.rgba(1, 1, 1, 0.7))
        font {
            pixelSize: 12
            family: "Symbols Nerd Font Mono"
        }
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: parent.scaleVal = 0.85
        onReleased: parent.scaleVal = 1.0
        onClicked: parent.clicked()
    }
}
