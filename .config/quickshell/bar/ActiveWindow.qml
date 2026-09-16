import QtQuick
import QtQuick.Layouts
import qs.services
import qs.themes

Text {
    id: titleText

    Layout.fillWidth: true
    Layout.minimumWidth: 40
    Layout.maximumWidth: Math.round(screen.width * 0.5)
    // Layout.alignment: Qt.AlignVCenter

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
