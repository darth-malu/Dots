import QtQuick

Rectangle {
    id: hbtn

    property string glyph
    property color tint: "#bd93f9"
    readonly property alias hovered: hbtnMa.containsMouse

    signal activated

    width: 30
    height: 30
    radius: 9
    color: hbtnMa.containsMouse ? Qt.rgba(hbtn.tint.r, hbtn.tint.g, hbtn.tint.b, 0.18) : Qt.rgba(1, 1, 1, 0.05)
    border.width: 1
    border.color: hbtnMa.containsMouse ? Qt.rgba(hbtn.tint.r, hbtn.tint.g, hbtn.tint.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 120
        }
    }

    scale: hbtnMa.pressed ? 0.92 : 1

    Behavior on scale {
        NumberAnimation {
            duration: 80
        }
    }

    Text {
        anchors.centerIn: parent
        text: hbtn.glyph
        color: hbtnMa.containsMouse ? Qt.lighter(hbtn.tint, 1.25) : "#b8bfcb"
        font {
            pixelSize: 14
            family: "Symbols Nerd Font Mono"
        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    MouseArea {
        id: hbtnMa

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: hbtn.activated()
    }
}
