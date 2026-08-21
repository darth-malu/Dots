pragma Singleton

import Quickshell
import Quickshell.Io

import QtQuick

Singleton {
    id: root

    // HOSTNAME
    FileView {
        id: hostFile
        // path: "file:///proc/sys/kernel/hostname"
        path: Qt.resolvedUrl("/proc/sys/kernel/hostname")
    }

    property string hostName: {
        var raw = hostFile.text().trim();
        return raw.length > 0 ? raw : "unknown";
    }
}
