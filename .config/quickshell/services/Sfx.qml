pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// wav one-shots played through pw-play (QtMultimedia is unavailable on this host)
Singleton {
    id: root

    readonly property string dir: Qt.resolvedUrl("../wav/") + ""

    function play(file) {
        const path = Qt.resolvedUrl("../wav/" + file).toString().replace("file://", "");
        Quickshell.execDetached(["sh", "-c", `pw-play '${path}' &`]);
    }

    function playPath(path) {
        Quickshell.execDetached(["sh", "-c", `pw-play '${path}' &`]);
    }
}
