pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.themes

// Avatar picker — overlay launcher in the rofi family (same DNA as the
// wallpaper picker):
// · scans ~/Pictures + the shell assets dir for images on every open
// · type to filter, Enter applies the highlighted tile
// · click applies · current avatar shows in the banner
// · Esc closes
PanelWindow {
    id: root

    visible: PickerState.avatarOpen
    implicitWidth: 860
    implicitHeight: 580
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var pics: []

    // re-scan the picture sources every time the picker opens
    onVisibleChanged: if (visible) {
        avatarScan.buf = "";
        avatarScan.running = true;
        search.forceActiveFocus();
    }

    readonly property var results: {
        var q = search.text.trim().toLowerCase();
        var list = root.pics;
        if (q.length === 0)
            return list;
        return list.filter(p => p.toLowerCase().includes(q));
    }

    function close() {
        search.text = "";
        PickerState.avatarOpen = false;
    }

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

            // ── header — mirrors the wallpaper picker's search bar ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "\uf007"
                    color: Themes.rofiAccent
                    font {
                        pixelSize: 13
                        family: "Symbols Nerd Font Mono"
                    }
                }

                TextField {
                    id: search

                    Layout.fillWidth: true
                    color: Themes.windowTextColor
                    selectByMouse: true
                    placeholderText: "filter by name…"
                    placeholderTextColor: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.4)
                    background: Rectangle {
                        color: "transparent"
                        implicitHeight: 16
                        radius: 4
                    }
                    Keys.onEscapePressed: root.close()
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
                            MiscState.applyAvatar(grid.currentItem.path_);
                            event.accepted = true;
                        }
                    }
                    Keys.onEnterPressed: {
                        if (grid.currentItem) {
                            MiscState.applyAvatar(grid.currentItem.path_);
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    visible: root.results.length > 0
                    text: root.results.length
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.4)
                    font {
                        pixelSize: 10
                        family: "ZedMono Nerd Font"
                    }
                }

                Rectangle {
                    implicitWidth: 18
                    implicitHeight: 18
                    radius: 9
                    color: closeMa.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.18) : "transparent"
                    border.width: 1
                    border.color: closeMa.containsMouse ? "#ff5555" : Themes.borderMuted

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: closeMa.containsMouse ? "#ff5555" : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.7)
                        font {
                            pixelSize: 9
                            family: "Symbols Nerd Font Mono"
                        }
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.close()
                    }
                }
            }

            // ── current avatar banner ──
            Rectangle {
                id: currentBanner

                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    ClippingRectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: "transparent"

                        Image {
                            id: bannerAvatar
                            anchors.fill: parent
                            source: MiscState.avatarUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: bannerAvatar.status !== Image.Ready
                            text: "\uf007"
                            color: Themes.muted
                            font {
                                pixelSize: 14
                                family: "Symbols Nerd Font Mono"
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "CURRENT AVATAR"
                            color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.4)
                            font {
                                pixelSize: 8
                                letterSpacing: 2
                                family: "ZedMono Nerd Font"
                            }
                        }

                        Text {
                            text: {
                                var a = MiscState.avatarPath;
                                if (a.length === 0)
                                    return "none";
                                return a.split("/").pop();
                            }
                            color: Themes.fg
                            font {
                                pixelSize: 11
                                bold: true
                                family: "Quicksand"
                            }
                        }
                    }
                }
            }

            // hairline
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            // ── picture grid ──
            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 4)
                cellHeight: Math.floor(cellWidth * 0.85) + 22
                model: root.results
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: currentIndex = count > 0 ? 0 : -1

                ScrollBar.vertical: ScrollBar {
                    policy: grid.contentHeight > grid.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: Item {
                    id: cellWrap

                    required property string modelData
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    readonly property string path_: modelData

                    ClippingRectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        height: grid.cellHeight - 24
                        radius: 9

                        Image {
                            anchors.fill: parent
                            source: cellWrap.path_
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize: Qt.size(256, 256)
                        }
                    }

                    Rectangle {
                        y: grid.cellHeight - 22
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        height: 18
                        radius: 4
                        color: "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: cellWrap.path_.split("/").pop()
                            color: grid.currentIndex === index ? Themes.accent : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.8)
                            elide: Text.ElideMiddle
                            font {
                                pixelSize: 9
                                family: "ZedMono Nerd Font"
                            }
                        }
                    }

                    // hover / keyboard-highlight ring
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        height: grid.cellHeight - 24
                        radius: 9
                        color: "transparent"
                        border.width: (grid.currentIndex === index || cellMa.containsMouse) ? 2 : 1
                        border.color: grid.currentIndex === index ? Themes.pink : Qt.rgba(1, 1, 1, 0.14)
                    }

                    // hover tint
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        height: grid.cellHeight - 24
                        radius: 9
                        color: cellMa.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.10) : "transparent"
                    }

                    MouseArea {
                        id: cellMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (!grid.moving)
                            grid.currentIndex = index
                        onClicked: MiscState.applyAvatar(cellWrap.path_)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.pics.length === 0
                    text: "no images found — drop pictures into ~/Pictures"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                    font {
                        pixelSize: 11
                        letterSpacing: 0.5
                        family: "ZedMono Nerd Font"
                    }
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    width: parent.width - 24
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0 && root.pics.length > 0
                    text: "no matches"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                    font {
                        pixelSize: 11
                        letterSpacing: 1
                        family: "ZedMono Nerd Font"
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.close()
    }

    Process {
        id: avatarScan
        running: false
        property string buf: ""

        command: ["sh", "-c", "find \"$HOME/Pictures\" \"$HOME/.config/quickshell/assets\" \"$HOME/Pictures/Wallpapers\" -maxdepth 3 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \\) 2>/dev/null | sort"]

        stdout: SplitParser {
            onRead: data => avatarScan.buf += data + "\n"
        }

        onExited: {
            root.pics = avatarScan.buf.split("\n").filter(p => p.length > 0);
        }
    }
}
