import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

RowLayout {
    id: root
    required property PwNode node
    required property string fallback
    required property color accent
    property string displayName

    Layout.fillWidth: true
    spacing: 6

    Text {
        text: {
            if (root.displayName && root.displayName.length > 0)
                return root.displayName;
            // NOTE: short circuit if displayName provided otherwise use desc
            const d = root.node?.description;
            return (d && d.length > 0) ? d : root.fallback;
        }
        color: root.accent
        elide: Text.ElideRight
        font {
            pixelSize: 10
            bold: true
            family: "Quicksand"
            letterSpacing: 1
        }
        Layout.fillWidth: true
    }

    Text {
        visible: root.node === null
        text: "unavailable"
        color: "#6272a4"
        font {
            pixelSize: 10
            family: "Monofur Nerd Font"
        }
    }
}
