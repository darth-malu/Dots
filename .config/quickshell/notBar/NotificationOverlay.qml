import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: root

    //screen: Quickshell.screens.find(m => m.name === Config.preferredMonitor)
    //screen: Quickshell.screens // TODO see if needed
    visible: NotificationState.notifOverlayOpen

    WlrLayershell.namespace: "quickshell:notifications:overlay"
    WlrLayershell.layer: WlrLayer.Overlay // Top - under fs, Bottom, Background - below bottom

    implicitHeight: notifs.height
    implicitWidth: notifs.width + 10

    exclusiveZone: 0

    color: "transparent"

    anchors {
        top: true
        right: true
    }

    margins.right: 2

    ColumnLayout {
        id: notifs

        Item {
            id: spaceFromBar
            implicitHeight: 7 // space from bar; y space 10::
        }

        Repeater {
            model: NotificationState.popupNotifs
            NotificationBox {
                id: notifBox
                required property int index // TODO investigate where index is fed from
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
