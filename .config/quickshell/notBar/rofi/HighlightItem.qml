import QtQuick
import Quickshell.Widgets

Item {
    id: root
    readonly property color accentColor: Qt.rgba(63 / 255, 167 / 255, 197 / 255, 0.82)

    ClippingRectangle {
        anchors.fill: parent
        color: Qt.rgba(72 / 255, 191 / 255, 227 / 255, 0.2)
        radius: 3

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: 2
            color: root.accentColor
        }
        Rectangle {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            width: 2
            color: root.accentColor
        }
    }
}
