import QtQuick
import Quickshell.Widgets

Rectangle {
    id: nixOsIcon
    implicitWidth: img.width
    implicitHeight: img.height
    // radius: 6
    color: "transparent"

    IconImage {
        id: img
        anchors.centerIn: parent
        implicitSize: 17
        source: Qt.resolvedUrl("../../svg/NixOS.svg")
        asynchronous: true
    }
}
