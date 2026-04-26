import Quickshell
import QtQuick
import Quickshell.Wayland
import qs.services
import qs.themes
import qs.customItems

BarText {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    text: ""
    // pointSize: 10
    // symbolSize: 5
    color: CaffeineService.enabled ? Themes.mprisIndicatorColor : Qt.rgba(1, 1, 1, 0.35)
    property bool caffeineOn: CaffeineService.enabled
    property Item mouseArea: mouseArea
    property int colorIndex: 0

    PersistentProperties {
        id: coloR
        property color rangi: CaffeineService.enabled ? Themes.mprisIndicatorColor : Qt.rgba(1, 1, 1, 0.35)
        reloadableId: "idleColor"
    }

    IdleMonitor {
        id: idleMonitor
        enabled: root.caffeineOn
        timeout: 5             // Seconds - before reporting idle state // FIXME: does not react
        respectInhibitors: true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: {
            CaffeineService.toggle();
        }
    }
}
