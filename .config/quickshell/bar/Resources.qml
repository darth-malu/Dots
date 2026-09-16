pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.customItems
import qs.services
import qs.themes

Loader {
    id: resourceLoader

    required property var host

    Layout.alignment: Qt.AlignVCenter
    active: ResourcesState.resourcesVisible

    visible: active

    sourceComponent: RowLayout {
        id: resourcesRow

        spacing: Themes.moduleGap // matches rightBlock's module gap in Bar.qml

        DiskBlock {
            host: resourceLoader.host
        }
        MemoryBlock {
            host: resourceLoader.host
        }
        CpuBlock {
            host: resourceLoader.host
        }
    }
}
