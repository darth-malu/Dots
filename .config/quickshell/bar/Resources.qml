import QtQuick
import QtQuick.Layouts
import qs.customItems
import qs.services

Loader {
    id: resourceLoader

    active: ResourcesState.resourcesVisible

    visible: active

    sourceComponent: RowLayout {
        id: resourcesRow

        PipewireBlock {}
        DiskBlock {}
        MemoryBlock {}
        CpuBlock {}
    }
}
