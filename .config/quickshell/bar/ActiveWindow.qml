import QtQuick
import qs.services
import qs.themes

Item {
    id: root

    // dynamic budget: shrink when the centered Mpris module is on stage so
    // the title never pushes into it or into the right-hand cluster — the
    // text elides at the cap instead of stretching the bar
    readonly property bool midVisible: MiscState.showMpris && MprisState.mprisVisible
    readonly property int maxW: Math.round(screen.width * (midVisible ? 0.24 : 0.34))

    implicitWidth: Math.min(titleText.implicitWidth, maxW)
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
