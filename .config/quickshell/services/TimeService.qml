pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property date currentDate: new Date()

    Timer {
        interval: 60000 // Check every minute
        running: true
        repeat: true
        onTriggered: root.currentDate = new Date()
    }

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
