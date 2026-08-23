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

    // arrival time (ms epoch) per notification id — QObject props can't be added dynamically
    property var notifTimes: ({})

    function notifTs(notif) {
        return root.notifTimes[notif.id] ?? 0;
    }

    // badge count for the qs bell
    readonly property int criticalCount: allNotifs.filter(n => n.urgency === 2).length

    // notifications carried over from a previous generation are already in
    // the history — re-adding them on every reload is what caused doubles
    function pushHistory(notif) {
        if (root.allNotifs.some(n => n.id === notif.id))
            return;
        allNotifs = [notif, ...allNotifs];
        if (allNotifs.length > 25)
            allNotifs = allNotifs.slice(0, 25);
    }

    function togglePanel() {
        if (notifOverlayOpen && !notifPanelOpen)
            notifOverlayOpen = false;

        notifPanelOpen = !notifPanelOpen;
    }

    function onNewNotif(notif) {
        console.log("[notif] app=" + notif.appName + " summary=" + notif.summary);

        let isMusic = (notif.appName == 'mzichi' || notif.appName == 'ncmpcpp' || notif.appName == 'spotifY');

        // nm-applet's stock connect popup is replaced by our themed one (emitted by NetworkState)
        if (notif.summary == "Connection established" && notif.appName != "Shell")
            return;

        // carried over from the last reload — already recorded, never re-queue
        if (notif.lastGeneration)
            return;

        // music toasts are redundant while quicksettings is open — never queue them
        if (isMusic && MiscState.qsOpen) {
            root.pushHistory(notif);
            return;
        }

        root.pushHistory(notif);

        // if (isSpotifyAd) return;

        if (isMusic) {
            popupNotifs = [notif];
        } else {
            popupNotifs = [notif, ...popupNotifs];
        }

        if (!notifPanelOpen)
            notifOverlayOpen = true;
    }

    // when quicksettings opens, purge any queued music toasts outright —
    // freezing them creates zombies that resurrect after closing qs
    Connections {
        target: MiscState

        function onQsOpenChanged() {
            if (!MiscState.qsOpen)
                return;
            const keep = root.popupNotifs.filter(n => !(n.appName == 'mzichi' || n.appName == 'ncmpcpp' || n.appName == 'spotifY'));
            if (keep.length !== root.popupNotifs.length) {
                root.popupNotifs = keep;
                if (keep.length === 0 && !root.notifPanelOpen)
                    root.notifOverlayOpen = false;
            }
        }
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
            root.notifTimes[notif.id] = Date.now();

            root.onNewNotif(notif);
            notif.closed.connect(() => {
                root.notifDismissByNotif(notif);
            });
        }
    }
}
