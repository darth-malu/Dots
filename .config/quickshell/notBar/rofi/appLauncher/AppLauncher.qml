import QtQuick
import Quickshell
import qs.services
import qs.notBar.rofi

Rofi {
    visible: RofiState.toggleAppLauncher

    modelIngest: RofiState.filterApps(searchField)

    delegateIngest: LauncherDelegate {
        required property var modelData
        iconUrl: Quickshell.iconPath(modelData.icon, "image-missing")
        app: TextLauncherDelegate {}
    }
}
