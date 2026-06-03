import QtQuick.Layouts
import qs.services
import QtQuick

RowLayout {
    spacing: 0
    MonitorBlock {
        id: gpu

        property bool showTemp: false

        readonly property color gpuColor: gpuPercent > 80 ? "#7CE577" : gpuPercent > 50 ? "#7CE577" : '#C6CAED' // #EEFC57

        readonly property int gpuPercent: ResourcesState.cpuPercent

        readonly property real gpuFreq: ResourcesState.cpuFreq

        readonly property real cpuTemp: ResourcesState.cpuTemp

        // TODO:Try JsonObject fonts
        readonly property string family: "quicksand"
        // antialiasing: true

        onClicked: {
            showTemp = !showTemp;
        }

        content: RowLayout {
            spacing: 16
            BarText {
                id: cpuText
                renderNative: true
                padding: 1
                font {
                    pixelSize: 12
                    bold: true
                    family: gpu.family
                }
                color: gpu.gpuColor
                symbolText: `❄️  ${gpu.gpuPercent}`
            }
            BarText {
                id: cpuFreqText
                visible: gpu.showTemp
                renderNative: true
                font {
                    pixelSize: 12
                    bold: true
                    family: gpu.family
                }
                symbolText: `🥶  ${gpu.gpuFreq} Ghz`
                baseColor: gpu.gpuColor
                // horizontalAlignment: Qt.AlignRight
            }
        }
    }
    MonitorBlock {
        radiusSide: "right"
        content: BarText {
            id: cpuTemp
            renderNative: true
            // topPadding: 1
            symbolText: `${gpu.cpuTemp} `
            baseColor: gpu.gpuColor
            font {
                pixelSize: 11
                bold: true
            }
        }
    }
}
