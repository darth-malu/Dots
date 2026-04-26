import QtQuick
import QtQuick.Controls

import Qt5Compat.GraphicalEffects

ProgressBar {
    id: root
    property int valueBarWidth: 23
    property int valueBarHeight: 12
    property color highlightColor: "yellow" //"#685496" //Filled part
    property color trackColor: "#F1D3F9" //empty part
    property alias radius: contentItem.radius
    property string text

    default property Item textMask: Item {}

    text: Math.round(value * 100) // provide value which is used for text calculations

    font {
        pixelSize: 11
        family: "VictorMono Nerd Font"
        // weight: text.length > 2 ? Font.Medium : Font.DemiBold
        weight: Font.Bold
    }

    background: Item {
        implicitHeight: valueBarHeight
        implicitWidth: valueBarWidth
    }

    contentItem: Rectangle {
        id: contentItem
        anchors.fill: parent
        radius: 2
        color: root.trackColor
        visible: false

        Rectangle {
            id: progressFill
            width: parent.width * root.visualPosition
            // height: parent.height - 6
            radius: contentItem.radius
            color: root.highlightColor
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: undefined
                // margins: 1
            }
        }
    }

    /*
    True: As * Am.
    False: As * (1 - Am).
    */

    OpacityMask {
        id: roundingMask
        visible: false
        anchors.fill: parent
        source: contentItem
        maskSource: Rectangle {
            width: contentItem.width
            height: contentItem.height
            radius: contentItem.radius
        }
    }

    OpacityMask {
        anchors.fill: parent
        source: roundingMask
        invert: true
        maskSource: root.textMask
    }
}
