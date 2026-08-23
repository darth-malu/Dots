import QtQuick
import Quickshell.Widgets
import qs.themes

Item {
    id: root
    readonly property color accentColor: Themes.rofiAccent

    ClippingRectangle {
        anchors.fill: parent
        color: Themes.rofiHighlightBg
        radius: 6

        // single rounded accent notch hugging the left edge
        Rectangle {
            anchors {
                left: parent.left
                leftMargin: 2
                verticalCenter: parent.verticalCenter
            }
            width: 3
            height: parent.height - 8
            radius: 1.5
            color: root.accentColor
        }
    }
}
