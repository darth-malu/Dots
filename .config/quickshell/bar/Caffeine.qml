import Quickshell
import QtQuick
import qs.services
import qs.customItems

// bar indicator — only occupies space while caffeine mode is active;
// sits to the right of quicksettings, click toggles it back off
BarBlock {
    id: root

    visible: CaffeineService.enabled

    onClicked: CaffeineService.toggle()

    content: Item {
        implicitWidth: 16
        implicitHeight: 16

        Text {
            anchors.centerIn: parent
            // \uf0f4 — fa-coffee (escape form survives edits that mangle PUA glyphs)
            text: "\uf0f4"
            color: "#ffb86c"
            font {
                pixelSize: 13
                family: "Symbols Nerd Font Mono"
            }
        }

        // soft breathing so the active state draws the eye without shouting
        SequentialAnimation on opacity {
            running: root.visible
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        }
    }
}
