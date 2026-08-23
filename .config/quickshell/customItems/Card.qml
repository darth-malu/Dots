import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title
    property string icon
    property color accent: "#f8f8f2"
    property int cardRadius: 10
    property int cardPadding: 5
    property color cardColor: "transparent"
    property real cardSpacing: 6

    Layout.fillWidth: true
    Layout.bottomMargin: 0
    radius: cardRadius
    color: cardColor

    implicitHeight: innerLayout.implicitHeight + cardPadding * 2

    default property alias content: innerLayout.children

    ColumnLayout {
        id: innerLayout
        x: cardPadding
        width: parent.width - cardPadding * 2
        y: cardPadding
        spacing: cardSpacing

        Text {
            visible: root.title.length > 0
            text: (root.icon ? root.icon + "  " : "") + root.title
            color: root.accent
            font {
                pixelSize: 10
                bold: true
                family: "Quicksand"
                letterSpacing: 1
            }
        }
    }
}
