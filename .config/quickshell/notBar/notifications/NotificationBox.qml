pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.services
import qs.themes

WrapperMouseArea {
    id: rootMouseArea

    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true

    property Notification n
    property real timestamp
    property real elapsed: Date.now()

    readonly property bool ifMusic: NotificationState.isMusic(n)

    // music bodies arrive as glyph-prefixed lines (see NotificationState.musicLines);
    // this mirrors what's on screen so the expand button gauges content size
    readonly property var musicRows: NotificationState.musicLines(n)
    // mirrors what's on screen (text + glyph) so the expand button gauges size
    readonly property string previewText: ifMusic ? musicRows.map(r => r.text + r.icon).join("") : (n.body ?? "")

    readonly property bool isImageIcon: n.image == "" && n.appIcon != ""

    readonly property string image: ifMusic ? (MprisState.albumArt) : isImageIcon ? n.appIcon : (n.image ?? "")

    property bool hasAppIcon: !(n.image == "" && n.appIcon != "")

    property int indexPopup: -1

    property int indexAll: -1

    // music toasts show the configurable album-art size (Settings → art size);
    // regular notifications keep the fixed 50px app icon
    property real iconSize: ifMusic ? MiscState.notifArtSize : 50

    property real iconRadius: iconSize / 5

    // critical notifications keep a red border; wifi connects show a signal-tinted wifi glyph
    readonly property bool urgent: n.urgency == NotificationUrgency.Critical
    readonly property bool isWifiConnect: n.appName == "Shell" && n.body.startsWith("signal · ")
    readonly property color accent: urgent ? "#ff5555" : Themes.accent

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
        id: container

        implicitWidth: Math.max(120, mainLayout.implicitWidth + 16)
        implicitHeight: mainLayout.implicitHeight
        radius: MiscState.notifRadius
        color: "#f0282a36"
        border.width: 1
        border.color: rootMouseArea.urgent ? Qt.rgba(1, 0.33, 0.33, 0.45) : Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.32)

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        RowLayout {
            id: mainLayout

            spacing: 10

            Item {
                id: songArtContainer
                visible: rootMouseArea.iconSize > 0
                implicitWidth: rootMouseArea.iconSize
                implicitHeight: rootMouseArea.iconSize
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.leftMargin: 2

                // TODO: cache all album art etc in persistent storage.
                // signal-strength tinted wifi glyph for connect notifications
                Text {
                    visible: rootMouseArea.isWifiConnect && rootMouseArea.image == ""
                    anchors.centerIn: parent
                    text: "\uf1eb"
                    color: NetworkState.wifiColor
                    font {
                        pixelSize: Math.round(rootMouseArea.iconSize * 0.6)
                        family: "Symbols Nerd Font Mono"
                    }
                }

                // default app icon for notifications that ship no art — music
                // gets a note, everything else a bell (matches the history list)
                Rectangle {
                    id: defaultIcon
                    visible: rootMouseArea.image == "" && !rootMouseArea.isWifiConnect
                    anchors.fill: songArtContainer
                    radius: container.radius - 2
                    color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.22)

                    Text {
                        anchors.centerIn: parent
                        text: rootMouseArea.ifMusic ? "\uf001" : "\uf0f3"
                        color: Themes.accentSoft
                        font {
                            pixelSize: Math.round(rootMouseArea.iconSize * 0.68)
                            family: "Symbols Nerd Font Mono"
                        }
                    }
                }

                ClippingWrapperRectangle {
                    id: songArt
                    visible: rootMouseArea.image != ""
                    radius: container.radius - 2
                    color: Themes.separator
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
                // music toasts park their short title/body against the top edge
                // beside the icon — floating them mid-card looks awkward there;
                // regular notifications keep their centered, historic look
                Layout.alignment: rootMouseArea.ifMusic ? Qt.AlignTop : Qt.AlignVCenter
                Layout.topMargin: 2

                // first line = the track title with its 󰎍 prefix split into the small
                // Symbols glyph, so the icon renders correctly beside the title
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        id: musicSummaryIcon
                        visible: rootMouseArea.ifMusic && NotificationState.glyphParts(rootMouseArea.n.summary).icon != ""
                        text: NotificationState.glyphParts(rootMouseArea.n.summary).icon
                        color: rootMouseArea.accent
                        Layout.alignment: Qt.AlignVCenter
                        font {
                            pixelSize: 10
                            family: "Symbols Nerd Font Mono"
                        }
                    }

                    Text {
                        id: summary
                        text: rootMouseArea.ifMusic ? NotificationState.cleanSummary(rootMouseArea.n.summary) : rootMouseArea.n.summary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        color: rootMouseArea.accent
                        font.family: MiscState.notifFont
                        font.pixelSize: MiscState.notifFontSize
                        font.weight: Font.Bold
                    }
                }

                // line break after the title — song toasts breathe between the
                // bold header and the artist/album rows below
                Item {
                    visible: rootMouseArea.ifMusic
                    Layout.fillWidth: true
                    implicitHeight: 6
                }

                // song body: one row per line, small glyph (Symbols) beside the
                // text (notifFont) — collapsible like the generic body below
                ColumnLayout {
                    id: musicBody
                    visible: rootMouseArea.ifMusic && rootMouseArea.musicRows.length > 0
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    spacing: 3

                    Repeater {
                        model: rootMouseArea.musicRows.slice(0, rootMouseArea.expanded ? 99 : 3)

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                visible: modelData.icon != ""
                                text: modelData.icon
                                color: Themes.mauve
                                Layout.alignment: Qt.AlignVCenter
                                font {
                                    pixelSize: 10
                                    family: "Symbols Nerd Font Mono"
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.text
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                                maximumLineCount: 1
                                color: Themes.dim
                                font.family: MiscState.notifFont
                                font.pixelSize: MiscState.notifFontSize
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                Text {
                    id: body
                    visible: !rootMouseArea.ifMusic
                    Layout.fillWidth: true
                    Layout.maximumWidth: 500
                    Layout.preferredWidth: implicitWidth
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: rootMouseArea.expanded ? 20 : (rootMouseArea.n.actions.length > 1 ? 1 : 3)
                    text: rootMouseArea.n.body
                    color: Themes.dim
                    font.family: MiscState.notifFont
                    font.pixelSize: MiscState.notifFontSize
                    font.weight: Font.Medium
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
                            color: actionMA.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.18) : Themes.separator

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: actionBtn.modelData.text
                                color: actionMA.containsMouse ? Themes.fg : Themes.dim
                                font {
                                    pixelSize: 10
                                    bold: true
                                    family: MiscState.notifFont
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
                visible: rootMouseArea.previewText.length > (rootMouseArea.n.actions.length > 1 ? 50 : 100)

                implicitWidth: 18
                implicitHeight: 18
                radius: 5
                color: expandMA.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Themes.separator

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: rootMouseArea.expanded ? "\uf077" : "\uf078"
                    color: Themes.dim
                    font {
                        pixelSize: 9
                        family: "Symbols Nerd Font Mono"
                    }
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
                color: closeMA.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.25) : Themes.separator

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    color: closeMA.containsMouse ? "#ff5555" : Themes.muted
                    font {
                        pixelSize: 9
                        family: "Symbols Nerd Font Mono"
                    }
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
