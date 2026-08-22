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

    readonly property string image: ifMusic ? (MprisState.player?.trackArtUrl ?? "") : isImageIcon ? n.appIcon : (n.image ?? "")

    property bool hasAppIcon: !(n.image == "" && n.appIcon != "")

    property int indexPopup: -1

    property int indexAll: -1

    property real iconSize: ifMusic ? 90 : 50

    property real iconRadius: iconSize / 5

    // critical notifications keep a red border; wifi connects tint to the current signal color
    readonly property bool urgent: n.urgency == NotificationUrgency.Critical
    readonly property bool isWifiConnect: n.summary == "Connection established" && n.appName == "Shell"
    readonly property color accent: isWifiConnect ? NetworkState.wifiColor : urgent ? "#ff5555" : "#bd93f9"

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

    Rectangle {
        id: outerBox

        implicitWidth: Math.min(360, Math.max(240, mainLayout.implicitWidth + 30))
        implicitHeight: mainLayout.implicitHeight + 20
        radius: 12
        color: "#f0282a36"
        border.width: 1
        border.color: rootMouseArea.urgent ? Qt.rgba(1, 0.33, 0.33, 0.45) : Qt.rgba(0.74, 0.58, 0.98, 0.32)

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        RowLayout {
            id: mainLayout

            anchors.centerIn: parent
            width: parent.width - 30
            spacing: 12

            Item {
                id: songArtContainer
                visible: rootMouseArea.image != ""
                implicitWidth: rootMouseArea.iconSize
                implicitHeight: rootMouseArea.iconSize
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.leftMargin: 2

                ClippingWrapperRectangle {
                    id: songArt
                    visible: rootMouseArea.image != ""
                    radius: rootMouseArea.iconRadius
                    color: "#343746"
                    anchors.fill: songArtContainer
                    IconImage {
                        implicitSize: songArtContainer.height
                        source: NotificationState.getImage(rootMouseArea.image)
                        asynchronous: true
                    }
                }
            }

            ColumnLayout {
                id: contentLayout
                spacing: 4
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        id: summary
                        text: rootMouseArea.n.summary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.maximumWidth: 260
                        color: rootMouseArea.accent
                        font {
                            pixelSize: 12
                            family: "Quicksand"
                            weight: Font.Bold
                            bold: true
                        }
                    }
                }

                Text {
                    id: body
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: rootMouseArea.expanded ? 20 : (rootMouseArea.n.actions.length > 1 ? 1 : 2)
                    text: rootMouseArea.n.body
                    color: rootMouseArea.isWifiConnect ? "#f8f8f2" : "#b8bfcb"
                    font { pixelSize: rootMouseArea.isWifiConnect ? 12 : 10; family: rootMouseArea.isWifiConnect ? "ZedMono Nerd Font" : "Quicksand" }
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
                            color: actionMA.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.18) : "#343746"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: actionBtn.modelData.text
                                color: actionMA.containsMouse ? "#f8f8f2" : "#b8bfcb"
                                font {
                                    pixelSize: 10
                                    bold: true
                                    family: "Quicksand"
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }
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

                implicitWidth: 18
                implicitHeight: 18
                radius: 5
                color: expandMA.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "#343746"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: rootMouseArea.expanded ? "\uf077" : "\uf078"
                    color: "#b8bfcb"
                    font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
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
                implicitWidth: 18
                implicitHeight: 18
                radius: 5
                color: closeMA.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.25) : "#343746"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    color: closeMA.containsMouse ? "#ff5555" : "#6272a4"
                    font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
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
