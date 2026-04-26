import QtQuick.Layouts
import qs.services
import qs.customItems
import QtQuick
import qs.themes

RowLayout {
    spacing: 0
    BarBlock {
        id: cpu
        border.width: 0

        property bool showTemp: false

        readonly property int cpuPercent: ResourcesState.cpuUsageString

        readonly property color cpuColor: cpuPercent > 80 ? "#7CE577" : cpuPercent > 50 ? "#7CE577" : '#C6CAED' // #EEFC57

        readonly property real cpuFreq: ResourcesState.cpuFreq

        readonly property real cpuTemp: ResourcesState.cpuTemp

        readonly property color cpuTempColor: this.cpuTemp > 80 ? "red" : this.cpuTemp > 60 ? "orange" : 'grey' // #EEFC57

        readonly property string family: "ZedMono Nerd Font"

        // antialiasing: true

        onClicked: {
            showTemp = !showTemp;
        }

        content: RowLayout {
            spacing: 0
            BarText {
                id: cpuText
                renderNative: true
                font: Themes.zedMono
                color: cpu.cpuColor
                symbolText: `  ${cpu.cpuPercent}` // 
            }
            BarText {
                id: cpuTemp
                visible: cpu.showTemp
                renderNative: true
                symbolText: `${cpu.cpuTemp}`
                baseColor: cpu.cpuTempColor
                font {
                    pixelSize: 12
                    bold: true
                    family: cpu.family
                }
            }
        }
    }
}
