import QtQuick
import Quickshell
import qs.services

BarBlock {
    id: disk
    underline: false

    required property var host

    readonly property string diskUsage: ResourcesState.btrfsDevice
    readonly property color diskColor: {
        const match = diskUsage.match(/(\d+\.?\d*)/);
        if (match) {
            if (match[0] < 10) {
                return "#7CE577";
            } else if (match[0] < 20) {
                return "#ff79c6";
            } else {
                return "#ccccccff";
            }
        }
        return "grey";
    }
    content: BarText {
        id: textRow
        renderNative: true
        font {
            pixelSize: 12
            bold: true
            family: "ZedMono Nerd Font"
        }
        baseColor: disk.diskColor
        symbolText: ` ${disk.diskUsage}`
    }

    PopupWindow {
        id: tooltipPopup
        visible: disk.mouseArea.containsMouse && ResourcesState.mediaDisks.length > 0
        grabFocus: false

        anchor.window: disk.host
        anchor.rect.x: {
            let globalPos = disk.mapToGlobal(0, 0);
            return globalPos.x + (disk.width / 2) - (width / 2);
        }
        anchor.rect.y: {
            let globalPos = disk.mapToGlobal(0, 0);
            return globalPos.y - implicitHeight - 4;
        }

        implicitWidth: tooltipText.implicitWidth + 16
        implicitHeight: tooltipText.implicitHeight + 8

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: "#1e1e2e"
            border.color: "#45475a"

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: ResourcesState.mediaDisks
                color: "#cdd6f4"
                font.pixelSize: 11
                font.family: "ZedMono Nerd Font"
            }
        }
    }
}
