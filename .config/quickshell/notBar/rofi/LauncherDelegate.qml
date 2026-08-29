import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell

Rectangle {
    id: root
    width: parent ? parent.width : 0
    height: appName.childrenRect.height + 15
    color: "transparent"

    default property Item app

    required property string iconUrl

    property var command

    property Component delegateMD

    required property int index
    property bool isCurrentItem: false

    // the owning ListView via the standard attached property — robust in
    // every delegate regardless of the creation context that built it
    // (a cross-file `itemLauncher: itemLauncher` self-binding stays null)
    readonly property ListView listView: ListView.view

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

    // interactive layer on TOP of the content so clicks/hovers never slip
    // through to the text behind; wheel is deliberately left alone so the
    // ListView/Flickable scrolls smoothly (native momentum + scrollbar)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: {
            if (!root.listView)
                return;
            root.listView.currentIndex = index;
            root.listView.activateCurrent();
        }
        onEntered: {
            if (!root.listView || root.listView.moving)
                return;
            root.listView.currentIndex = index;
        }
    }
}