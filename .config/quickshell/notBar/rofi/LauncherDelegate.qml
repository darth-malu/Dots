import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell

Rectangle {
    id: root
    width: parent ? parent.width : 0
    height: appName.childrenRect.height + 15
    color: "transparent"

    // default property alias content: appName.data // data is the contents of an instance children list
    default property Item app

    required property string iconUrl

    property var command

    property Component delegateMD

    // delegates are created before parenting — guard so ListView setup
    // doesn't spam null-parent TypeErrors
    required property int index
    property bool isCurrentItem: parent ? (parent.currentIndex === index) : false

    property MouseArea mouseArea: mouseArea

    // the launcher ListView lives in Rofi.qml — its id is out of scope in
    // this file, so instances bind it explicitly (was a silent ReferenceError)
    property var itemLauncher

    property string windowTitle

    MouseArea {
        id: mouseArea
        anchors.fill: root
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: {
            itemLauncher.currentIndex = index;
            itemLauncher.activateCurrent();
        }
        // no onWheel here — the ListView/Flickable in Rofi.qml handles the
        // wheel natively (smooth, momentum, scrollbar-synced, and works with
        // trackpad pixel deltas). A per-delegate manual contentY jump bypassed
        // all of that and only moved in coarse 120px/notch steps.
    }

    RowLayout {
        anchors.verticalCenter: root.verticalCenter
        spacing: 20

        IconImage {
            id: appIcon
            source: root.iconUrl
            implicitSize: 18
            asynchronous: true
            Layout.leftMargin: 10
        }

        Item {
            id: appName
            Layout.fillHeight: true // Centers text lol
            children: root.app
        }
    }
}
