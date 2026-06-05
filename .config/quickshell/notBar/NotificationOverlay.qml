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

    margins.right: 6

    ColumnLayout {
        id: notifs
        spacing: 6

        Item {
            id: spaceFromBar
            implicitHeight: 10
        }

        Repeater {
            model: NotificationState.popupNotifs
            NotificationBox {
                id: notifBox
                required property int index
                n: NotificationState.popupNotifs[index]
                timestamp: Date.now()
                indexPopup: index
                onContainsMouseChanged: {
                    if (!containsMouse)
                        notificationTimeout.restart();
                    else
                        notificationTimeout.stop();
                }
                Timer {
                    id: notificationTimeout
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
