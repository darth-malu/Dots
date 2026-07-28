import QtQuick
import qs.themes

Text {
    id: modelText
    text: modelData ? (modelData.wayland ? modelData.wayland.title : modelData.title) : ""
    color: Themes.rofiDelegateText
    font: Themes.rofiFont
}
