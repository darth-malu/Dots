import QtQuick
import Quickshell.Widgets
import qs.themes

Item {
    id: root
    readonly property color accentColor: Themes.rofiAccent

    ClippingRectangle {
        anchors.fill: parent
        color: Themes.rofiHighlightBg
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
