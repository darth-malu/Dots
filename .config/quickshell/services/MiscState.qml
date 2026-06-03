pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Singleton {
    id: root

    property bool activateLinux: false

    property bool toggleAppLauncher: false

    property bool toggleOpenWindows: false

    property bool toggleClipHist: false

    property bool toggleRofi: false

    property bool toggleSysTray: false

    property date currentDate: new Date()

    property bool showPopup: false

    readonly property var currentToplevels: Hyprland.toplevels
}
