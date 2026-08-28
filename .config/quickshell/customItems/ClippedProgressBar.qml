import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.themes

ProgressBar {
    id: root
    property int valueBarWidth: 23
    property int valueBarHeight: 12
    property color highlightColor: "yellow"
    property color trackColor: Themes.separator
    property alias radius: barBg.radius
    property string text

    default property Item textMask: Item {}

    text: Math.round(value * 100)

    font {
        pixelSize: 11
        family: "VictorMono Nerd Font"
        weight: Font.Bold
    }

    background: Item {
        implicitHeight: valueBarHeight
        implicitWidth: valueBarWidth
    }

    contentItem: Item {
        id: contentItem
        anchors.fill: parent

        Rectangle {
            id: barBg
            anchors.fill: parent
            radius: 2
            color: root.trackColor
        }

        Rectangle {
            id: barFill
            width: parent.width * root.visualPosition
            height: parent.height
            radius: 2
            color: root.highlightColor
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: root.textMask
        }
    }
}
