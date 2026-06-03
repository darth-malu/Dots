import QtQuick
import Quickshell
import qs.services
import qs.notBar.rofi

Rofi {
    visible: RofiState.toggleOpenWindows
    modelIngest: RofiState.filterWindows(searchField)
    delegateIngest: LauncherDelegate {
        required property var modelData
        iconUrl: Quickshell.iconPath(modelData?.wayland.appId, "image-missing")
        app: DelegateText {}
    }
}
