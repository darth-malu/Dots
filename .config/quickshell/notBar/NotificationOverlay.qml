import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: root

    visible: NotificationState.notifOverlayOpen

    WlrLayershell.namespace: "quickshell:notifications:overlay"
    WlrLayershell.layer: WlrLayer.Overlay

    implicitHeight: notifs.height
    implicitWidth: notifs.width + 12

    exclusiveZone: 0

    color: "transparent"

    anchors {
        top: true
        right: true
    }

    margins.right: 0

    ColumnLayout {
        id: notifs
        spacing: 6

        Item {
            id: spaceFromBar
            implicitHeight: 4
        }

        Repeater {
            model: NotificationState.popupNotifs
            delegate: NotificationBox {
                id: notifBox
                required property int index
                n: NotificationState.popupNotifs[index]
                timestamp: Date.now()
                indexPopup: index
                onContainsMouseChanged: {
                    if (!containsMouse)
                        notifTimer.restart();
                    else
                        notifTimer.stop();
                }
                Timer {
                    id: notifTimer
                    running: true
                    interval: (notifBox.n.expireTimeout > 0 && notifBox.n.expireTimeout < 10 ? notifBox.n.expireTimeout : 4) * 1000
                    onTriggered: {
                        NotificationState.notifDismissByNotif(notifBox.n);
                    }
                }
            }
        }
    }
}
