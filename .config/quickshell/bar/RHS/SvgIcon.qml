import QtQuick
import QtQuick.Effects
import qs.services

Item {
    id: root
    width: 16
    height: 16
    required property string icon
    property color color: "#ff79c6"

    Image {
        id: svg
        anchors.fill: parent
        source: root.icon
        sourceSize.width: 16
        sourceSize.height: 16
        visible: false          // show the tinted copy instead
    }

    MultiEffect {
        anchors.fill: svg
        source: svg
        colorization: 1.0       // 0 = original ... 1 = fully pink
        colorizationColor: root.color
    }
}
