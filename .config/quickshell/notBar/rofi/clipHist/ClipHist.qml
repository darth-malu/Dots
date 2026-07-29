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

    readonly property var jsonData: {
        try {
            var t = clipmanJson.text().trim();
            return t.length > 0 ? JSON.parse(t) : [];
        } catch (e) {
            return [];
        }
    }

    delegateIngest: LauncherDelegate {
        required property var modelData
        iconUrl: ""
        // iconUrl: Quickshell.iconPath(modelData?.wayland?.appId ?? "", "image-missing")
        app: TextClipHistDelegate {}
    }
}
