pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // single source of truth for "now" — the same SystemClock the bar clock
    // renders from, so the reminder spinner, calendar math and reminder
    // grouping can never drift from what the user sees in the panel
    readonly property date currentDate: clock.date

    readonly property string time: {
        Qt.formatDateTime(clock.date, "h:mm"); //ddd MMM d hh:mm:ss AP t yyyy
    }

    readonly property string date: {
        Qt.formatDateTime(clock.date, "d ddd, MMMM");
    }

    readonly property string dateTime: {
        Qt.formatDateTime(clock.date, "d ddd, MMMM - HH:mm");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes //Seconds::, Minutes
    }

}
