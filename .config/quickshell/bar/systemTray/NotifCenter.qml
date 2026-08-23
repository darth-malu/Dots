import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.customItems
import qs.services

BarBlock {
    id: root

    required property var host
    visible: MiscState.showNotifTray

    readonly property var history: {
        const all = NotificationState.allNotifs;
        return [...all.filter(n => n.urgency === 2), ...all.filter(n => n.urgency !== 2)];
    }

    onClicked: NetworkState.notifCenterVisible = !NetworkState.notifCenterVisible

    content: Item {
        implicitWidth: 18
        implicitHeight: 18

        Text {
            anchors.centerIn: parent
            text: "\uf0a2"
            color: NetworkState.notifCenterVisible || NotificationState.criticalCount > 0 ? "#bd93f9" : "#6272a4"
            font {
                pixelSize: 14
                family: "Symbols Nerd Font Mono"
            }
        }

        // red dot while an undismissed critical exists
        Rectangle {
            visible: NotificationState.criticalCount > 0
            anchors.right: parent.right
            anchors.top: parent.top
            implicitWidth: 6
            implicitHeight: 6
            radius: 3
            color: "#ff5555"
        }
    }

    LazyLoader {
        loading: true

        PopupWindow {
            id: notifPopup

            visible: NetworkState.notifCenterVisible
            grabFocus: true
            color: MiscState.popupSolidBg ? "#282a36" : "transparent"

            anchor.window: root.host
            anchor.rect.x: {
                let g = root.mapToGlobal(0, 0);
                return g.x + (root.width / 2) - (width / 2);
            }

            anchor.rect.y: 33

            implicitWidth: 344
            implicitHeight: centerCol.implicitHeight + 24

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#282a36"
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

                Shortcut {
                    sequence: "Escape"
                    onActivated: NetworkState.notifCenterVisible = false
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: NetworkState.notifCenterVisible = false
                }

                ColumnLayout {
                    id: centerCol

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // ticks the "x ago" labels without per-row timers
                    property real nowTs: Date.now()

                    Timer {
                        interval: 15000
                        running: NetworkState.notifCenterVisible
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: centerCol.nowTs = Date.now()
                    }

                    // header row — count · clear-all chip
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: {
                                const n = NotificationState.allNotifs.length;
                                return n === 0 ? "no notifications" : `${n} notification${n === 1 ? "" : "s"}`;
                            }
                            color: "#f8f8f2"
                            font {
                                pixelSize: 12
                                bold: true
                                family: "Quicksand"
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: NotificationState.allNotifs.length > 0
                            implicitWidth: clearTxt.implicitWidth + 16
                            implicitHeight: 20
                            radius: 9
                            color: clearMa.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.15) : "#343746"

                            Text {
                                id: clearTxt

                                anchors.centerIn: parent
                                text: "\uf1f8  clear"
                                color: clearMa.containsMouse ? "#ff5555" : "#b8bfcb"
                                font {
                                    pixelSize: 10
                                    bold: true
                                    family: "Symbols Nerd Font Mono, Quicksand"
                                }
                            }

                            MouseArea {
                                id: clearMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationState.closeAll()
                            }
                        }
                    }

                    // history rows — criticals pinned to the top
                    Repeater {
                        model: root.history

                        delegate: Rectangle {
                            id: histRow

                            required property var modelData
                            required property int index

                            readonly property bool urgent: histRow.modelData.urgency === 2

                            // brief check-mark feedback after copying the content
                            property bool copied: false

                            // the app's own icon — image first, theme icon fallback
                            readonly property string iconUrl: {
                                const n = histRow.modelData;
                                const img = String(n?.image ?? "");
                                if (img.length > 0)
                                    return NotificationState.getImage(img);
                                const app = String(n?.appIcon ?? "");
                                return app.length > 0 ? NotificationState.getImage(app) : "";
                            }

                            Layout.fillWidth: true
                            implicitHeight: 42
                            radius: 9
                            color: histMouse.hovered ? Qt.rgba(1, 1, 1, 0.05) : histRow.urgent ? Qt.rgba(1, 0.33, 0.33, 0.08) : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 9

                                Rectangle {
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    radius: 7
                                    color: "#343746"

                                    IconImage {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        visible: histRow.iconUrl != ""
                                        source: histRow.iconUrl
                                        asynchronous: true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: histRow.iconUrl == ""
                                        text: "\uf0f3"
                                        color: "#6272a4"
                                        font {
                                            pixelSize: 13
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }
                                }

                                ColumnLayout {
                                    spacing: 1
                                    Layout.fillWidth: true

                                    Text {
                                        Layout.fillWidth: true
                                        text: histRow.modelData.summary
                                        color: histRow.urgent ? "#ff5555" : "#bd93f9"
                                        elide: Text.ElideRight
                                        font {
                                            pixelSize: 12
                                            bold: true
                                            family: "Quicksand"
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: histRow.modelData.body.length > 0
                                        text: histRow.modelData.body.split(String.fromCharCode(10)).join(" ")
                                        color: "#b8bfcb"
                                        elide: Text.ElideRight
                                        font {
                                            pixelSize: 11
                                            family: "Quicksand"
                                        }
                                    }
                                }

                                Text {
                                    text: NotificationState.humanTime(Math.floor(NotificationState.notifTs(histRow.modelData) / 1000), Math.floor(centerCol.nowTs / 1000))
                                    color: "#6272a4"
                                    font {
                                        pixelSize: 9
                                        family: "ZedMono Nerd Font"
                                    }
                                }

                                // copy pill — left-click copies title + body,
                                // right-click copies the body only
                                Rectangle {
                                    id: rowCopyPill

                                    implicitWidth: 24
                                    implicitHeight: 20
                                    radius: 6
                                    color: rowCopyMa.containsMouse || histRow.copied
                                        ? Qt.rgba(0.741, 0.576, 0.976, histRow.copied ? 0.18 : 0.12)
                                        : "transparent"

                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: histRow.copied ? "\uf00c" : "\uf328"
                                        color: histRow.copied ? "#50fa7b" : rowCopyMa.containsMouse ? "#bd93f9" : "#6272a4"
                                        font {
                                            pixelSize: 12
                                            family: "Symbols Nerd Font Mono"
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: 120 }
                                        }
                                    }

                                    // hover hint — floats above the pill so the
                                    // row never shifts; doubles as copied toast
                                    Rectangle {
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: 3
                                        anchors.right: parent.right
                                        z: 60
                                        radius: 6
                                        implicitWidth: hintLabel.implicitWidth + 14
                                        implicitHeight: 17
                                        color: "#282a36"
                                        border.width: 1
                                        border.color: histRow.copied ? Qt.rgba(0.31, 0.98, 0.48, 0.5) : Qt.rgba(0.74, 0.58, 0.98, 0.45)
                                        visible: opacity > 0.01
                                        opacity: rowCopyMa.containsMouse || histRow.copied ? 1 : 0

                                        Behavior on opacity {
                                            ColorAnimation { duration: 120 }
                                        }

                                        Text {
                                            id: hintLabel

                                            anchors.centerIn: parent
                                            text: histRow.copied ? "copied" : "copy · right-click body"
                                            color: histRow.copied ? "#50fa7b" : "#bd93f9"
                                            font {
                                                pixelSize: 8
                                                bold: true
                                                letterSpacing: 0.5
                                                family: "Quicksand"
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: rowCopyMa

                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: mouse => {
                                            const n = histRow.modelData;
                                            // right button grabs just the message body
                                            const text = mouse.button === Qt.RightButton
                                                ? String(n.body ?? "")
                                                : [n.summary, n.body].filter(s => s && s.length > 0).join("\n");
                                            if (text.length === 0)
                                                return;
                                            Quickshell.execDetached(["sh", "-c", `printf %s '${text.replace(/'/g, "'\\''")}' | wl-copy`]);
                                            histRow.copied = true;
                                            copiedTimer.restart();
                                        }
                                    }

                                    Timer {
                                        id: copiedTimer
                                        interval: 900
                                        onTriggered: histRow.copied = false
                                    }
                                }

                                Text {
                                    text: "\uf00d"
                                    color: rowCloseMa.containsMouse ? "#ff5555" : "#6272a4"
                                    font {
                                        pixelSize: 12
                                        family: "Symbols Nerd Font Mono"
                                    }

                                    MouseArea {
                                        id: rowCloseMa

                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const idx = NotificationState.allNotifs.indexOf(histRow.modelData);
                                            if (idx !== -1)
                                                NotificationState.notifCloseByAll(idx);
                                        }
                                    }
                                }
                            }

                            HoverHandler {
                                id: histMouse
                            }
                        }
                    }

                    Text {
                        visible: NotificationState.allNotifs.length === 0
                        text: "nothing here yet"
                        color: "#6272a4"
                        font {
                            pixelSize: 11
                            italic: true
                            family: "Quicksand"
                        }
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
