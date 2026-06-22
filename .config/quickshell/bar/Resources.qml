pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.customItems
import qs.services

Loader {
    id: resourceLoader

    required property var host

    Layout.alignment: Qt.AlignVCenter
    active: ResourcesState.resourcesVisible

    visible: active

    sourceComponent: RowLayout {
        id: resourcesRow

        DiskBlock {
            host: resourceLoader.host
        }
        MemoryBlock {}
        CpuBlock {}
        GpuBlock {}
    }
}
