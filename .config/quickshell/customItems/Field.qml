import QtQuick
import QtQuick.Controls
import qs.themes

// compact single-line input for inline forms (git monitor "add repo" etc.)
TextField {
    id: field

    signal returnPressed

    property string placeholder: ""
    onPlaceholderChanged: field.placeholderText = placeholder

    color: Themes.windowTextColor
    selectByMouse: true
    font.pixelSize: 9
    placeholderText: placeholder
    placeholderTextColor: Qt.rgba(Themes.dim.r, Themes.dim.g, Themes.dim.b, 0.5)

    background: Rectangle {
        implicitHeight: 18
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Themes.separator
    }

    Keys.onReturnPressed: field.returnPressed()
    Keys.onEnterPressed: field.returnPressed()
}