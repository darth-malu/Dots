pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQml                         // resolvedUrl

Singleton {
    id: root

    property var popupNotifs: []
    property var allNotifs: []
    property var defaultNotifTimeout: 5000
    property bool notifOverlayOpen: false
    property bool notifPanelOpen: false

    property var lastNotif: null

    function togglePanel() {
        if (notifOverlayOpen && !notifPanelOpen)
            notifOverlayOpen = false;

        notifPanelOpen = !notifPanelOpen;
    }

    function onNewNotif(notif) {
        let isMusic = (notif.appName == 'mzichi' || notif.appName == 'ncmpcpp' || notif.appName == 'spotifY');
        // let isSpotifyAd = notif.summary.startsWith("󰎍    Listen to music");

        allNotifs = [notif, ...allNotifs];

        if (notif.lastGeneration) // if notif was carried over from last reload
            return;

        // if (isSpotifyAd) return;

        if (isMusic) {
            popupNotifs = [notif];
        } else {
            popupNotifs = [notif, ...popupNotifs];
        }

        if (!notifPanelOpen)
            notifOverlayOpen = true;
    }

    function showLastNotif(notif) {
        popupNotifs = [notif];
        if (!notifPanelOpen)
            notifOverlayOpen = true;
    }

    function notifDismissByNotif(notif) {
        popupNotifs = popupNotifs.filter(n => n != notif);
        if (popupNotifs.length == 0)
            notifOverlayOpen = false;
    }

    function notifCloseByNotif(notif) {
        popupNotifs = popupNotifs.filter(n => n != notif); // filter out notif from popupNotifs
        allNotifs = allNotifs.filter(n => n != notif);
        notif.dismiss();
        if (popupNotifs.length == 0) // close overlay if no more pop ups in list
            notifOverlayOpen = false;
    }

    function notifDismissByPopup(idPopups) {
        let notif = popupNotifs[idPopups];
        notifDismissByNotif(notif);
    }

    function notifDismissByAll(idAll) {
        let notif = allNotifs[idAll];
        notifDismissByNotif(notif);
    }

    function notifCloseByAll(idAll) {
        let notif = allNotifs[idAll];
        notifCloseByNotif(notif);
    }

    function notifCloseByPopup(idPopup) {
        let notif = popupNotifs[idPopup];
        notifCloseByNotif(notif);
    }

    function dismissAll() {
        popupNotifs = [];
        notifOverlayOpen = false;
    }

    function closeAll() {
        allNotifs = [];
        notifOverlayOpen = false;
    }

    function getImage(image: string): string {
        if (image.search(/:\/\//) != -1)
            return Qt.resolvedUrl(image);
        return Quickshell.iconPath(image);
    }

    function humanTime(timestamp: int, elapsed: int): string {
        const MINUTE = 60;
        const HOUR = 60 * MINUTE;
        const DAY = 24 * HOUR;

        const diff = elapsed - timestamp;

        if (diff < 15) {
            return "now";
        } else if (diff < MINUTE) {
            return "seconds ago";
        } else if (diff < HOUR) {
            return `${diff}m ago`;
        } else if (diff < DAY) {
            return `${Math.round(diff / HOUR)}h ago`;
        } else if (diff < 2 * DAY) {
            return "yesterday";
        } else {
            return `${Math.round(diff / DAY)} days ago`;
        }
    }

    NotificationServer {
        id: notifServer
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        onNotification: notif => {
            notif.tracked = true;
            root.lastNotif = notif;

            // let isDuplicate = root.allNotifs.some(existingNotif => (existingNotif.id === notif.id));

            // if (!isDuplicate) {
            //     root.onNewNotif(notif);
            // } else {
            //     Quickshell.execDetached(["notify-send", "Duplicate Id blocked" + notif.id]);
            // }

            root.onNewNotif(notif);
            notif.closed.connect(() => {
                root.notifDismissByNotif(notif);
            });
        }
    }
}
