import QtQuick
import QtQuick.Layouts
import qs.customItems
import qs.services

Loader {
    id: resourceLoader

    required property var host

    active: ResourcesState.resourcesVisible

    visible: active

    sourceComponent: RowLayout {
        id: resourcesRow

        PipewireBlock {}
        DiskBlock { host: resourceLoader.host }
        MemoryBlock {}
        CpuBlock {}
        GpuBlock {}
    }
}
