import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    Layout.preferredWidth: contentContainer.implicitWidth + 4 // :+8

    Layout.preferredHeight: contentContainer.implicitHeight // 30::

    Layout.alignment: Qt.AlignVCenter

    radius: height / 2

    property Item content

    property Item mouseArea: mouseArea

    property string text

    property bool dim: false

    property bool underline: false

    property color underlineColor: 'orange'

    signal clicked(var mouse)
    signal leftClicked
    signal rightClicked
    signal middleClicked
    signal wheel(var event)

    color: "transparent"

    Item {
        id: contentContainer
        implicitWidth: root.content.implicitWidth
        implicitHeight: root.content.implicitHeight
        anchors.centerIn: parent
        children: root.content
    }

    MouseArea {
        id: mouseArea
        anchors.fill: root
        hoverEnabled: true
        acceptedButtons: Qt.RightButton | Qt.LeftButton | Qt.MiddleButton | Qt.ForwardButton | Qt.BackButton | Qt.NoButton
        onClicked: mouse => {
            root.clicked(mouse);
            if (mouse.button === Qt.LeftButton) root.leftClicked();
            else if (mouse.button === Qt.RightButton) root.rightClicked();
            else if (mouse.button === Qt.MiddleButton) root.middleClicked();
        }
        onWheel: event => root.wheel(event)
        // propagateComposedEvents: true
    }

    // While line underneath workspace
    Rectangle {
        id: wsLine
        width: root.width
        radius: 12
        height: 0.1

        color: {
            if (root.underline)
                return root.underlineColor;
            return "transparent";
        }
        anchors.bottom: parent.bottom
    }
}
