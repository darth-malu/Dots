import QtQuick
import Quickshell
import qs.services
import qs.notBar.rofi
import Quickshell.Io

Rofi {
    id: root
    visible: RofiState.toggleClipHist

    modelIngest: jsonData

    property var clipHist

    FileView {
        id: clipmanJson
        path: "file:///home/malu/.local/share/clipman.json"

        watchChanges: true      // when changes are made on disk reload the file's content
        onFileChanged: reload()
        // onLoaded: root.processJson()
    }

    readonly property var jsonData: JSON.parse(clipmanJson.text())

    delegateIngest: LauncherDelegate {
        required property var modelData
        iconUrl: ""
        app: TextClipHistDelegate {}
    }
}
