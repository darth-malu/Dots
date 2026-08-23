import QtQuick
import Quickshell.Widgets

Rectangle {
    id: nixOsIcon
    implicitWidth: 24
    implicitHeight: 24
    radius: 6
    color: "transparent"

    IconImage {
        anchors.centerIn: parent
        implicitSize: 17
        source: Qt.resolvedUrl("../../svg/NixOS.svg")
        asynchronous: true
    }
}
