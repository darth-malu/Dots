import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    Layout.preferredWidth: contentContainer.implicitWidth + 4 // :+8

    Layout.preferredHeight: contentContainer.implicitHeight // 30::

    Layout.alignment: Qt.AlignVCenter

    property Item content

    property Item mouseArea: mouseArea

    property string radiusSide: "left"

    property string text

    // property bool dim: false

    property bool underline: false

    property color underlineColor: 'orange'

    signal clicked

    // antialiasing: true

    border {
        width: radius > 0 ? 1 : 0
        color: 'red'
        pixelAligned: true
    }

    topLeftRadius: if (radiusSide == "left")
        height / 2

    bottomLeftRadius: if (radiusSide == "left")
        height / 2

    topRightRadius: if (radiusSide == "right")
        height / 2

    bottomRightRadius: if (radiusSide == "right")
        height / 2

    radius: radiusSide == "null" ?? 0

    property string hoveredBgColor: "#666666"

    // color: {
    //     if (mouseArea.containsMouse)
    //         return hoveredBgColor;
    //     return "transparent";
    // }

    color: "transparent"

    // states: [
    //     State {
    //         when: mouseArea.containsMouse
    //         PropertyChanges {
    //             target: root
    //         }
    //     }
    // ]

    // Behavior on color {
    //     ColorAnimation {
    //         duration: 150
    //     }
    // }

    Item {
        id: contentContainer
        implicitWidth: root.content.implicitWidth
        implicitHeight: root.content.implicitHeight
        // NOTE key difference with BarBlock
        // implicitHeight: 17
        anchors.centerIn: parent
        children: root.content
    }

    MouseArea {
        id: mouseArea
        anchors.fill: root
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | PointerDevice.Mouse | PointerDevice.TouchPad
        onClicked: root.clicked()
        // propagateComposedEvents: true
    }

    // While line underneath workspace
    Rectangle {
        id: wsLine
        implicitWidth: root.width
        radius: 12
        height: 1

        color: {
            if (root.underline)
                return root.underlineColor;
            return "transparent";
        }
        anchors.bottom: parent.bottom
    }
}
