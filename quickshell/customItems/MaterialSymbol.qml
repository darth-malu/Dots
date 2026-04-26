import QtQuick

StyledText {
    id: root
    property real iconSize: 10
    // property real fill: 0
    // property real truncatedFill: Math.round(fill * 100) / 100 // Reduce memory consumption spikes from constant font remapping
    // renderType: fill !== 0 ? Text.CurveRendering : Text.NativeRendering
    font {
        // hintingPreference: Font.PreferFullHinting
        family: "JetBrainsMono Nerd Font"
        pixelSize: iconSize
        // weight: Font.Normal + (Font.DemiBold - Font.Normal) * fill
        // variableAxes: {
        //     "FILL": truncatedFill,
        //     "opsz": iconSize
        // }
    }
}
