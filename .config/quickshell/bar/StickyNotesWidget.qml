pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.themes
import qs.services
import qs.customItems

BarBlock {
    id: root
    required property var host

    readonly property int noteCount: NotesState.count()
    readonly property bool open: MiscState.showStickyPopup

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton || mouse.button === Qt.MiddleButton)
            MiscState.showStickyPopup = !MiscState.showStickyPopup;
    }

    content: Item {
        implicitWidth: stickyRow.implicitWidth
        implicitHeight: stickyRow.implicitHeight

        RowLayout {
            id: stickyRow
            anchors.centerIn: parent
            spacing: 6

            BarText {
                symbolText: "\uf040"
                paddingg: 0
                bottomPadding: 2
                font: Themes.monoSmall
                baseColor: root.noteCount > 0 ? Themes.orange : Themes.dim
            }

            BarText {
                symbolText: root.noteCount > 0 ? root.noteCount.toString() : "0"
                paddingg: 0
                bottomPadding: 2
                font: Themes.monoSmall
                baseColor: root.noteCount > 0 ? Themes.orange : Themes.dim
            }
        }
    }

    Loader {
        active: MiscState.showStickyPopup
        sourceComponent: stickyPopupComp
    }

    Component {
        id: stickyPopupComp

        PopupWindow {
            id: popup
            visible: MiscState.showStickyPopup
            grabFocus: true
            color: "transparent"

            anchor.window: root.host
            anchor.rect.x: {
                let globalPos = root.mapToGlobal(0, 0);
                const cx = globalPos.x + (root.width / 2) - (width / 2);
                const scrW = root.host?.screen?.width ?? 1920;
                return Math.max(6, Math.min(cx, scrW - width - 6));
            }
            anchor.rect.y: root.host.height + 8

            implicitWidth: popupCard.implicitWidth + 24
            implicitHeight: popupCard.implicitHeight + 24

            Keys.onEscapePressed: MiscState.showStickyPopup = false

            Rectangle {
                id: popupCard
                focus: true
                radius: 10
                anchors.fill: parent
                border.width: 1
                border.color: Themes.borderColor
                color: Themes.popupCardBg

                width: 260
                implicitWidth: contentCol.implicitWidth + 24
                implicitHeight: contentCol.implicitHeight + 24

                ColumnLayout {
                    id: contentCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "\uf040"
                            color: Themes.orange
                            font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                        }

                        Text {
                            text: "Sticky Notes"
                            color: Themes.fg
                            font { pixelSize: 12; family: "Quicksand"; bold: true }
                            Layout.fillWidth: true
                        }

                        // add note button
                        Rectangle {
                            implicitWidth: addNoteBtnLabel.implicitWidth + 14
                            implicitHeight: 20
                            radius: 5
                            color: addNoteMa.containsMouse ? Qt.rgba(Themes.orange.r, Themes.orange.g, Themes.orange.b, 0.22) : "transparent"
                            border.width: 1
                            border.color: addNoteMa.containsMouse ? Qt.rgba(Themes.orange.r, Themes.orange.g, Themes.orange.b, 0.35) : Themes.borderColor

                            Text {
                                id: addNoteBtnLabel
                                anchors.centerIn: parent
                                text: "\uf067 Note"
                                color: Themes.fg
                                font { pixelSize: 9; family: "Quicksand"; bold: true }
                            }
                            MouseArea {
                                id: addNoteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotesState.addNote("note")
                            }
                        }

                        // add todo button
                        Rectangle {
                            implicitWidth: addTodoBtnLabel.implicitWidth + 14
                            implicitHeight: 20
                            radius: 5
                            color: addTodoMa.containsMouse ? Qt.rgba(Themes.orange.r, Themes.orange.g, Themes.orange.b, 0.22) : "transparent"
                            border.width: 1
                            border.color: addTodoMa.containsMouse ? Qt.rgba(Themes.orange.r, Themes.orange.g, Themes.orange.b, 0.35) : Themes.borderColor

                            Text {
                                id: addTodoBtnLabel
                                anchors.centerIn: parent
                                text: "\uf067 Todo"
                                color: Themes.fg
                                font { pixelSize: 9; family: "Quicksand"; bold: true }
                            }
                            MouseArea {
                                id: addTodoMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotesState.addNote("todo")
                            }
                        }
                    }

                    // separator
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Themes.borderColor
                    }

                    // note list
                    ListView {
                        id: noteList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: Math.min(contentHeight, 260)
                        clip: true
                        spacing: 4
                        model: NotesState.model

                        delegate: Rectangle {
                            id: noteItem
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: noteRow.implicitHeight + 12
                            radius: 6
                            color: noteItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            border.width: 1
                            border.color: Themes.borderColor

                            property var palette: [
                                { accent: "#ffb86c" },
                                { accent: "#8be9fd" },
                                { accent: "#ff79c6" },
                                { accent: "#50fa7b" },
                                { accent: "#bd93f9" }
                            ]
                            property color noteAccent: palette[(noteItem.modelData.color ?? 0) % palette.length].accent
                            readonly property bool isTodo: (noteItem.modelData.kind ?? "note") === "todo"

                            RowLayout {
                                id: noteRow
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                // color dot
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 6
                                    implicitHeight: 6
                                    radius: 3
                                    color: noteItem.noteAccent
                                }

                                // icon
                                Text {
                                    text: noteItem.isTodo ? "\uf0ca" : "\uf040"
                                    color: noteItem.noteAccent
                                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // preview text
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: noteItem.isTodo
                                            ? (noteItem.modelData.items?.length ?? 0) + " items"
                                            : (noteItem.modelData.text ?? "").slice(0, 50) || "(empty note)"
                                        color: Themes.fg
                                        font { pixelSize: 10; family: "Quicksand"; bold: true }
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        visible: noteItem.isTodo
                                        Layout.fillWidth: true
                                        text: {
                                            const items = noteItem.modelData.items ?? [];
                                            const done = items.filter(i => i.d).length;
                                            return done + "/" + items.length + " done";
                                        }
                                        color: Themes.dim
                                        font { pixelSize: 8; family: "ZedMono Nerd Font" }
                                        elide: Text.ElideRight
                                    }
                                }

                                // toggle visibility
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    radius: 4
                                    color: visMa.containsMouse ? Qt.rgba(Themes.orange.r, Themes.orange.g, Themes.orange.b, 0.22) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: noteItem.modelData.visible ? "\uf06e" : "\uf070"
                                        color: noteItem.modelData.visible ? Themes.orange : Themes.dim
                                        font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                                    }
                                    MouseArea {
                                        id: visMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotesState.setVisible(noteItem.index, !noteItem.modelData.visible)
                                    }
                                }

                                // delete
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    radius: 4
                                    color: delMa.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.18) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf00d"
                                        color: delMa.containsMouse ? "#ff5555" : Themes.dim
                                        font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                                    }
                                    MouseArea {
                                        id: delMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotesState.removeById(noteItem.modelData.id)
                                    }
                                }
                            }
                        }

                        // empty state
                        Text {
                            anchors.centerIn: parent
                            visible: noteList.count === 0
                            text: "no notes yet — click + to add one"
                            color: Themes.dim
                            font { pixelSize: 10; family: "Quicksand" }
                        }
                    }
                }
            }
        }
    }
}
