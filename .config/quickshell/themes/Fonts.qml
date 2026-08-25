import Quickshell.Io

JsonObject {
    property AllFonts font: AllFonts {}

    component AllFonts: JsonObject {
        property FontFamily family: FontFamily {}
        property FontSize size: FontSize {}
    }

    component FontFamily: JsonObject {
        property string mono: "JetBrainsMono"
        property string sans: "Quicksand"
    }

    component FontSize: JsonObject {
        property int small: 11
        property int normal: 12
        property int large: 14
        property int extraLarge: 16
    }
}
