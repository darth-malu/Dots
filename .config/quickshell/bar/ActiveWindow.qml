import QtQuick
import QtQuick.Layouts
import qs.services
import qs.themes

Item {
    id: root

    // absorbs ALL the leftover space between the workspace cluster and the RHS
    // modules, so long titles elide right at the live boundary instead of at a
    // fixed percentage — a safety cap keeps it from ever touching far modules
    Layout.fillWidth: true
    Layout.minimumWidth: 40
    Layout.maximumWidth: Math.round(screen.width * 0.6)
    Layout.alignment: Qt.AlignVCenter

    implicitHeight: titleText.implicitHeight

    Text {
        id: titleText

        anchors.fill: parent
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        text: ActiveWindowState.currentWindow
        color: Themes.windowTextColor
        font: Themes.windowTextFont
        renderType: Text.NativeRendering
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}