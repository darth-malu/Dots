pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.themes
import qs.services

WrapperMouseArea {
    id: rootMouseArea

    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton //Qt.AllButtons
    hoverEnabled: true

    property Notification n
    property real timestamp
    property real elapsed: Date.now()

    /*
    IMAGE: icon associated with the notification eg. a profile picture in a messaging app
    appIcon: sending app's icon, if none provided .. the icon form an associated desktop entry will be retrieved. if none found = ""
     */
    readonly property bool ifMusic: (n.appName == 'mzichi' || n.appName == 'ncmpcpp' || n.appName == 'spotifY')

    readonly property bool isImageIcon: n.image == "" && n.appIcon != ""

    readonly property string image: ifMusic ? (MprisState.player?.trackArtUrl) : isImageIcon ? n.appIcon : n.image // Return appIcon of application or image if image present.

    property bool hasAppIcon: !(n.image == "" && n.appIcon != "") // negate ... no image + appIcon present = image + appIcon absent

    property int indexPopup: -1

    property int indexAll: -1

    property real iconSize: ifMusic ? 90 : 50

    property real iconRadius: iconSize / 5 // 12??

    property bool showTime: false

    property bool expanded: false

    onClicked: mouse => {
        // actions: list <NotificationAction>
        if (mouse.button == Qt.LeftButton && rootMouseArea.n.actions != []) {
            rootMouseArea.n.actions[0].invoke();
        } else if (mouse.button == Qt.RightButton) {
            if (indexAll != -1)
                NotificationState.notifDismissByAll(indexAll);
            else if (indexPopup != -1)
                NotificationState.notifDismissByPopup(indexPopup);
        } else if (mouse.button == Qt.MiddleButton) {
            NotificationState.dismissAll();
        }
    }

    ElapsedTimer {
        id: elapsedTimer
    }

    Timer {
        running: rootMouseArea.showTime
        interval: 1000
        repeat: true
        onTriggered: rootMouseArea.elapsed = elapsedTimer.elapsed()
    }

    Rectangle {
        id: outerBox
        implicitWidth: Math.max(120, mainLayout.implicitWidth + 10)
        implicitHeight: mainLayout.implicitHeight
        radius: rootMouseArea.ifMusic ? 12 : 8
        color: Themes.bgBlur
        border {
            width: rootMouseArea.ifMusic ? 0 : 1
            color: Qt.rgba(0.627, 0.125, 0.941, 0.78) // Qt.rgba(0.63, 0.13, 0.94, 0.5) //"#A020F0" Qt.rgba(0.63, 0.13, 0.94, 0.3)
        }

        RowLayout {
            id: mainLayout
            spacing: 8 // picture and text space

            Item {
                id: songArtContainer
                visible: rootMouseArea.image != ""
                implicitWidth: rootMouseArea.iconSize
                implicitHeight: rootMouseArea.iconSize
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.leftMargin: 2
                Layout.rightMargin: 4

                ClippingWrapperRectangle {
                    id: songArt
                    visible: rootMouseArea.image != ""
                    radius: outerBox.radius - 2 // TODO make only TopLeft/bottom radius
                    color: "transparent"
                    // anchors.fill: parent
                    IconImage {
                        implicitSize: songArtContainer.height
                        source: NotificationState.getImage(rootMouseArea.image)
                        asynchronous: true
                    }
                }

                ClippingWrapperRectangle {
                    id: appIconRect
                    // visible: rootMouseArea.hasAppIcon
                    visible: false
                    radius: 2
                    color: "transparent"
                    anchors {
                        horizontalCenter: songArtContainer.right
                        verticalCenter: songArtContainer.bottom
                        horizontalCenterOffset: -4
                        verticalCenterOffset: -4
                    }
                    IconImage {
                        implicitSize: 16
                        source: NotificationState.getImage(rootMouseArea.n.appIcon)
                        asynchronous: true
                    }
                }
            }

            ColumnLayout {
                id: contentLayout
                spacing: 4
                RowLayout {
                    Text {
                        id: summary
                        text: rootMouseArea.n.summary
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        color: Qt.rgba(171 / 255, 141 / 255, 237 / 255, 0.98)
                        font {
                            pointSize: 10
                            family: 'Quicksand medium'
                            weight: Font.Bold
                            bold: true
                        }
                    }
                    Text {
                        id: currentTime
                        visible: rootMouseArea.showTime
                        Layout.alignment: Qt.AlignRight
                        text: NotificationState.humanTime(rootMouseArea.timestamp, rootMouseArea.elapsed)
                    }
                }

                Text {
                    id: body
                    Layout.maximumWidth: 500 // For absurdly long stuff
                    Layout.preferredWidth: implicitWidth
                    elide: Text.ElideRight
                    // visible: text ? true : false
                    wrapMode: Text.Wrap
                    font.weight: Font.Medium
                    maximumLineCount: rootMouseArea.expanded ? 20 : (rootMouseArea.n.actions.length > 1 ? 1 : 2)
                    text: rootMouseArea.n.body
                    color: 'white'
                }

                RowLayout {
                    visible: rootMouseArea.n.actions.length > 1

                    Layout.fillWidth: true
                    implicitHeight: actionRepeater.implicitHeight

                    Repeater {
                        id: actionRepeater
                        model: rootMouseArea.n.actions.slice(1) // This returns array of all elements in root.n.actions after index [0] to end

                        WrapperMouseArea {
                            id: actionButtonMA
                            required property NotificationAction modelData
                            hoverEnabled: true
                            implicitHeight: actionButton.implicitHeight
                            Layout.fillWidth: true

                            onPressed: () => {
                                modelData.invoke();
                            }

                            Rectangle {
                                id: actionButton
                                radius: 16
                                color: actionButtonMA.containsMouse ? Themes.buttonDisabledHover : Themes.buttonDisabled
                                implicitHeight: buttonText.implicitHeight
                                Layout.fillWidth: true
                                Text {
                                    id: buttonText
                                    anchors.centerIn: parent
                                    text: actionButtonMA.modelData.text
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            id: buttonLayout
            visible: rootMouseArea.containsMouse
            implicitHeight: 16

            anchors {
                top: parent.top
                right: parent.right
                topMargin: 8
                rightMargin: 8
            }

            WrapperMouseArea {
                id: expandButton

                visible: body.text.length > (rootMouseArea.n.actions.length > 1 ? 50 : 100)

                property string sourceIcon: rootMouseArea.expanded ? "go-up-symbolic" : "go-down-symbolic"

                hoverEnabled: true
                Layout.fillHeight: true
                implicitWidth: 16

                onPressed: () => rootMouseArea.expanded = !rootMouseArea.expanded

                Rectangle {
                    radius: implicitHeight / 2
                    color: expandButton.containsMouse ? Themes.buttonDisabledHover : Themes.buttonDisabled
                    implicitWidth: 16
                    implicitHeight: 16

                    IconImage {
                        source: Quickshell.iconPath(expandButton.sourceIcon)
                        anchors.centerIn: parent
                        implicitHeight: parent.implicitHeight - 4
                        implicitWidth: parent.implicitWidth - 4
                        // asynchronous: true
                    }
                }
            }

            WrapperMouseArea {
                id: closeButton
                hoverEnabled: true
                Layout.fillHeight: true
                implicitWidth: 16

                onPressed: () => {
                    if (rootMouseArea.indexAll != -1)
                        NotificationState.notifCloseByAll(rootMouseArea.indexAll);
                    else if (rootMouseArea.indexPopup != -1)
                        NotificationState.notifCloseByPopup(rootMouseArea.indexPopup);
                }

                Rectangle {
                    radius: 16
                    color: closeButton.containsMouse ? Themes.buttonDisabledHover : Themes.buttonDisabled
                    implicitWidth: 16
                    implicitHeight: 16

                    IconImage {
                        source: Quickshell.iconPath("process-stop-symbolic")
                        anchors.centerIn: parent
                        implicitHeight: parent.implicitHeight - 4
                        implicitWidth: parent.implicitHeight - 4
                        asynchronous: true
                    }
                }
            }
        }
    }
}
