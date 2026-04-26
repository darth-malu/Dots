import QtQuick
import qs.services
import qs.themes

BarBlock {
    id: memory

    readonly property int memoryPercent: ResourcesState.memPercent

    readonly property color memoryColor: memoryPercent > 90 ? "#7CE577" : '#ccccccff'

    content: BarText {
        id: memoryText
        renderNative: true
        font: Themes.zedMono
        baseColor: memory.memoryColor
        symbolText: `  ${memory.memoryPercent}`
    }
}
