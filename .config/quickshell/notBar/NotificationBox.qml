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

    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true

    property Notification n
    property real timestamp
    property real elapsed: Date.now()

    readonly property bool ifMusic: (n.appName == 'mzichi' || n.appName == 'ncmpcpp' || n.appName == 'spotifY')

    readonly property bool isImageIcon: n.image == "" && n.appIcon != ""

    readonly property string image: ifMusic ? (MprisState.player?.trackArtUrl) : isImageIcon ? n.appIcon : n.image

    property bool hasAppIcon: !(n.image == "" && n.appIcon != "")

    property int indexPopup: -1

    property int indexAll: -1

    property real iconSize: ifMusic ? 90 : 50

    property real iconRadius: iconSize / 5

    property bool showTime: false

    property bool expanded: false

    onClicked: mouse => {
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
        implicitWidth: Math.max(120, mainLayout.implicitWidth + 16)
        implicitHeight: mainLayout.implicitHeight
        radius: rootMouseArea.ifMusic ? 12 : 8
        color: Themes.bgBlur
        border {
            width: rootMouseArea.ifMusic ? 0 : 1
            color: Qt.rgba(0.627, 0.125, 0.941, 0.78)
        }

        RowLayout {
            id: mainLayout
            spacing: 10

            Item {
                id: songArtContainer
                visible: rootMouseArea.image != ""
                implicitWidth: rootMouseArea.iconSize
                implicitHeight: rootMouseArea.iconSize
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                Layout.leftMargin: 6

                ClippingWrapperRectangle {
                    id: songArt
                    visible: rootMouseArea.image != ""
                    radius: outerBox.radius - 2
                    color: "transparent"
                    IconImage {
                        implicitSize: songArtContainer.height
                        source: NotificationState.getImage(rootMouseArea.image)
                        asynchronous: true
                    }
                }

                ClippingWrapperRectangle {
                    id: appIconRect
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
                spacing: 6
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                Layout.rightMargin: 8

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
                    Layout.maximumWidth: 500
                    Layout.preferredWidth: implicitWidth
                    elide: Text.ElideRight
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
                    spacing: 4

                    Repeater {
                        id: actionRepeater
                        model: rootMouseArea.n.actions.slice(1)

                        Rectangle {
                            id: actionBtn
                            required property NotificationAction modelData
                            implicitHeight: 24
                            Layout.fillWidth: true
                            radius: 6
                            color: actionMA.containsMouse ? Qt.lighter("#313244", 1.2) : "#313244"

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: actionBtn.modelData.text
                                color: actionMA.containsMouse ? "#cdd6f4" : "#a6adc8"
                                font {
                                    pixelSize: 10
                                    bold: true
                                    family: "Quicksand"
                                }

                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: actionMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: actionBtn.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            id: buttonLayout
            visible: rootMouseArea.containsMouse
            implicitHeight: 20

            anchors {
                top: parent.top
                right: parent.right
                topMargin: 6
                rightMargin: 6
            }
            spacing: 2

            Rectangle {
                id: expandButton
                visible: body.text.length > (rootMouseArea.n.actions.length > 1 ? 50 : 100)

                property string sourceIcon: rootMouseArea.expanded ? "go-up-symbolic" : "go-down-symbolic"

                implicitWidth: 20
                implicitHeight: 20
                radius: 4
                color: expandMA.containsMouse ? Qt.lighter("#313244", 1.3) : "#313244"

                Behavior on color { ColorAnimation { duration: 100 } }

                IconImage {
                    source: Quickshell.iconPath(expandButton.sourceIcon)
                    anchors.centerIn: parent
                    implicitHeight: 12
                    implicitWidth: 12
                }

                MouseArea {
                    id: expandMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: rootMouseArea.expanded = !rootMouseArea.expanded
                }
            }

            Rectangle {
                id: closeButton
                implicitWidth: 20
                implicitHeight: 20
                radius: 4
                color: closeMA.containsMouse ? Qt.lighter("#f38ba8", 1.3) : "#313244"

                Behavior on color { ColorAnimation { duration: 100 } }

                IconImage {
                    source: Quickshell.iconPath("process-stop-symbolic")
                    anchors.centerIn: parent
                    implicitHeight: 12
                    implicitWidth: 12
                }

                MouseArea {
                    id: closeMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: {
                        if (rootMouseArea.indexAll != -1)
                            NotificationState.notifCloseByAll(rootMouseArea.indexAll);
                        else if (rootMouseArea.indexPopup != -1)
                            NotificationState.notifCloseByPopup(rootMouseArea.indexPopup);
                    }
                }
            }
        }
    }
}
