import QtQuick
import QtQuick.Layouts
import qs.themes

Rectangle {
    implicitHeight: 1
    implicitWidth: parent ? parent.width : 100
    color: Themes.separator
    Layout.fillWidth: true
    Layout.topMargin: 4
    Layout.bottomMargin: 4
}
