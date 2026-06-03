import QtQuick
import qs.services

BarBlock {
    id: disk
    underline: false

    readonly property string diskUsage: ResourcesState.darth_pool
    readonly property color diskColor: {
        const match = diskUsage.match(/(\d+\.?\d*)/); // returns list...get first match...number only eg 37.8
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
        id: diskText
        renderNative: true
        font {
            pixelSize: 12
            bold: true
            family: "ZedMono Nerd Font"
        }
        baseColor: disk.diskColor
        symbolText: ` ${disk.diskUsage}` //🗃
    }
}
