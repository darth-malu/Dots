import QtQuick
import QtQuick.Layouts

RowLayout {
    required property string icon
    required property string text
    required property color color

    Layout.fillWidth: true

    Text {
        text: `${parent.icon}  ${parent.text}`
        color: parent.color
        font {
            pixelSize: 10
            bold: true
            family: "Quicksand"
            letterSpacing: 1
        }
    }
    Item {
        Layout.fillWidth: true
    }
}
