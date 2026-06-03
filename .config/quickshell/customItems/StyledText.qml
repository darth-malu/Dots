import QtQuick

Text {
    id: root

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    font {
        hintingPreference: Font.PreferDefaultHinting
        family: "lato"
        pixelSize: 15
    }
    color: "white"
}
