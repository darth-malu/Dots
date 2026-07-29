import QtQuick
import qs.themes

// TODO: make one template for all Delegate Texts

Text {
    id: modelText
    text: modelData ? (modelData.wayland ? modelData.wayland.title : modelData.title) : ""
    color: Themes.rofiDelegateText
    font: Themes.rofiFont
}
