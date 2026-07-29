import QtQuick
import qs.themes

Text {
    id: modelText
    text: modelData.replace(/\n/g, " ")
    color: Themes.rofiDelegateText
    font: Themes.rofiFont
    elide: Text.ElideRight
    maximumLineCount: 1
}
