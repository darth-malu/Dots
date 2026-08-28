pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.themes

import "EmojiData.js" as EmojiData
import "."

// Emoji picker — overlay launcher in the rofi family:
// · type to filter by name/keyword, Enter copies the highlighted emoji
// · click copies · recents row on top (persisted via PickerState)
// · Esc closes
PanelWindow {
    id: root

    visible: PickerState.emojiOpen
    implicitWidth: 420
    implicitHeight: 380
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // emoji chars most-recently used
    property var recentEmojis: PickerState.recentEmojis

    // search-filtered dataset
    readonly property var results: EmojiData.search(search.text)

    function copyEmoji(char) {
        PickerState.pushRecentEmoji(char);
        Quickshell.execDetached(["sh", "-c",
            `printf '%s' '${char}' | wl-copy && notify-send -a Emoji -t 1500 '${char}  copied to clipboard'`]);
        close();
    }

    function close() {
        search.text = "";
        PickerState.emojiOpen = false;
    }

    onVisibleChanged: if (visible)
        search.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Themes.launcherBg
        border.width: 1
        border.color: Themes.rofiBorder

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header — same design as the rofi/app-launcher header:
            // mode glyph · borderless search · result count ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "\uf118"
                    color: Themes.rofiAccent
                    font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                }

                TextField {
                    id: search

                    Layout.fillWidth: true
                    color: Themes.windowTextColor
                    selectByMouse: true
                    background: Rectangle {
                        color: "transparent"
                        implicitHeight: 16
                        radius: 4
                    }
                    Keys.onEscapePressed: root.close()
                    // arrows steer the grid from the search field
                    property int gridCols: Math.max(1, Math.floor(grid.width / grid.cellWidth))
                    Keys.onLeftPressed: event => {
                        if (grid.count === 0)
                            return;
                        grid.currentIndex = grid.currentIndex > 0 ? grid.currentIndex - 1 : grid.count - 1;
                        event.accepted = true;
                    }
                    Keys.onRightPressed: event => {
                        if (grid.count === 0)
                            return;
                        grid.currentIndex = grid.currentIndex < grid.count - 1 ? grid.currentIndex + 1 : 0;
                        event.accepted = true;
                    }
                    Keys.onUpPressed: event => {
                        if (grid.count === 0)
                            return;
                        grid.currentIndex = Math.max(0, grid.currentIndex - search.gridCols);
                        event.accepted = true;
                    }
                    Keys.onDownPressed: event => {
                        if (grid.count === 0)
                            return;
                        grid.currentIndex = Math.min(grid.count - 1, grid.currentIndex + search.gridCols);
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: {
                        if (grid.currentItem) {
                            root.copyEmoji(grid.currentItem.char_);
                            event.accepted = true;
                        }
                    }
                    Keys.onEnterPressed: {
                        if (grid.currentItem) {
                            root.copyEmoji(grid.currentItem.char_);
                            event.accepted = true;
                        }
                    }
                }

            Text {
                visible: root.results.length > 0
                text: root.results.length
                color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.4)
                font { pixelSize: 10; family: "ZedMono Nerd Font" }
            }
            }

            // ── recents strip — only when it has content and no active query ──
            ColumnLayout {
                visible: root.recentEmojis.length > 0 && search.text.length === 0
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "RECENT"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.45)
                    font { pixelSize: 8; letterSpacing: 2; family: "ZedMono Nerd Font" }
                }

                RowLayout {
                    spacing: 2

                    Repeater {
                        model: root.recentEmojis.slice(0, 14)

                        delegate: Rectangle {
                            id: recentCell

                            required property var modelData
                            required property int index

                            readonly property string char_: modelData

                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 34
                            implicitHeight: 30
                            radius: 7
                            color: recMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.char_
                                font.pixelSize: 18
                            }

                            MouseArea {
                                id: recMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyEmoji(recentCell.char_)
                            }
                        }
                    }
                }
            }

            // ── grid of results ──
            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 8)
                cellHeight: 42
                model: root.results
                boundsBehavior: Flickable.StopAtBounds
                // fresh query → highlight the first match for Enter
                onCountChanged: currentIndex = count > 0 ? 0 : -1

                ScrollBar.vertical: ScrollBar {
                    policy: grid.contentHeight > grid.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: Item {
                    id: cellWrap

                    required property var modelData
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    // char_ avoids clashing with Item's `font`-adjacent names;
                    // modelData[0] is the emoji char
                    readonly property string char_: modelData[0]

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 7
                        color: cellMa.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.18) : "transparent"
                        border.width: grid.currentIndex === index ? 1 : 0
                        border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.55)

                        Text {
                            anchors.centerIn: parent
                            text: cellWrap.char_
                            font.pixelSize: 20
                        }

                        ToolTip.visible: cellMa.containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: cellWrap.modelData[1]
                    }

                    MouseArea {
                        id: cellMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: grid.currentIndex = index
                        onClicked: root.copyEmoji(cellWrap.char_)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: grid.count === 0
                    text: "no matches"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                    font { pixelSize: 11; letterSpacing: 1; family: "ZedMono Nerd Font" }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.close()
    }
}
