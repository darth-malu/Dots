import QtQuick
import qs.services
import qs.themes

Text {
    id: myText
    readonly property int chop: 68
    text: {
        if (MprisState.mprisVisible) {
            var str = ActiveWindowState.currentWindow;
            return str.length > chop ? str.slice(0, chop) + '..' : str;
        } else {
            return ActiveWindowState.currentWindow;
        }
    }
    color: Themes.windowTextColor
    font: Themes.windowTextFont
    renderType: Text.NativeRendering
    elide: Text.ElideRight
}
