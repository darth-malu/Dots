pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.themes

// Wallpaper picker — overlay launcher in the rofi family:
// · type to filter by name, Enter applies the highlighted wallpaper
// · click applies · current one is ringed in the accent color
// · Esc closes
PanelWindow {
    id: root

    visible: PickerState.wallpaperOpen
    implicitWidth: 920
    implicitHeight: 640
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // re-scan the wallpaper dir every time the picker opens
    onVisibleChanged: if (visible) {
        WallpaperService._refreshList();
        search.forceActiveFocus();
    }

    // name-filtered dataset — star filter narrows the grid to favorites only
    property bool favFilter: false

    readonly property var results: {
        var q = search.text.trim().toLowerCase();
        var list = WallpaperService.wallpaperList;
        if (root.favFilter)
            list = list.filter(p => WallpaperService.isFavorite(p));
        if (q.length === 0)
            return list;
        return list.filter(p => p.toLowerCase().includes(q));
    }

    function applyWallpaper(path) {
        if (!path || path.length === 0)
            return;
        WallpaperService.setWallpaper(path);
        close();
    }

    function close() {
        search.text = "";
        PickerState.wallpaperOpen = false;
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

            // ── header — same design as the rofi/app-launcher header ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "\uf03e"
                    color: Themes.rofiAccent
                    font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
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
                    // vim-motion movement — Ctrl+H/J/K/L
                    Keys.onPressed: event => {
                        if (!(event.modifiers & Qt.ControlModifier))
                            return;
                        if (grid.count === 0) {
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_J) {
                            grid.currentIndex = Math.min(grid.count - 1, grid.currentIndex + search.gridCols);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_K) {
                            grid.currentIndex = Math.max(0, grid.currentIndex - search.gridCols);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_H) {
                            grid.currentIndex = grid.currentIndex > 0 ? grid.currentIndex - 1 : grid.count - 1;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_L) {
                            grid.currentIndex = grid.currentIndex < grid.count - 1 ? grid.currentIndex + 1 : 0;
                            event.accepted = true;
                        }
                    }
                    Keys.onReturnPressed: {
                        if (grid.currentItem) {
                            root.applyWallpaper(grid.currentItem.path_);
                            event.accepted = true;
                        }
                    }
                    Keys.onEnterPressed: {
                        if (grid.currentItem) {
                            root.applyWallpaper(grid.currentItem.path_);
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

                // favorites-only filter for the grid
                Rectangle {
                    visible: root.results.length > 0 || root.favFilter
                    implicitWidth: favChipText.implicitWidth + 14
                    implicitHeight: 16
                    radius: 8
                    color: root.favFilter ? Qt.rgba(0.31, 0.98, 0.48, 0.12) : "transparent"
                    border.width: 1
                    border.color: root.favFilter ? "#50fa7b" : Themes.rofiBorder

                    Text {
                        id: favChipText
                        anchors.centerIn: parent
                        text: "\uf005 favorites"
                        color: root.favFilter ? "#50fa7b" : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.7)
                        font { pixelSize: 8; letterSpacing: 0.5; family: "ZedMono Nerd Font" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.favFilter = !root.favFilter
                    }
                }
            }

                    // ── current wallpaper banner ──
                    Rectangle {
                        id: currentBanner

                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 9
                        color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.4)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Image {
                                Layout.preferredWidth: 88
                                Layout.fillHeight: true
                                source: WallpaperService.current.length > 0
                                    ? WallpaperService.thumbSource(WallpaperService.current, WallpaperService.thumbVersion)
                                    : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                clip: true
                                sourceSize: { const s = 128; return Qt.size(s, s); }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "CURRENT"
                                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.4)
                                    font { pixelSize: 8; letterSpacing: 2; family: "ZedMono Nerd Font" }
                                }

                                Text {
                                    text: WallpaperService.current.length > 0 ? WallpaperService.current.split("/").pop() : "none"
                                    elide: Text.ElideMiddle
                                    color: Themes.fg
                                    font { pixelSize: 12; bold: true; family: "Quicksand" }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    readonly property color on: "#50fa7b"
                                    readonly property color off: Themes.borderMuted

                                    // desktop clock
                                    Rectangle {
                                        implicitWidth: clockChipText.implicitWidth + 14
                                        implicitHeight: 16
                                        radius: 8
                                        color: WallpaperService.desktopClock ? Qt.rgba(0.31, 0.98, 0.48, 0.12) : "transparent"
                                        border.width: 1
                                        border.color: WallpaperService.desktopClock ? parent.on : parent.off

                                        Text {
                                            id: clockChipText
                                            anchors.centerIn: parent
                                            text: "\uf017 clock"
                                            color: parent.border.color
                                            font { pixelSize: 8; letterSpacing: 0.5; family: "ZedMono Nerd Font" }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: WallpaperService.desktopClock = !WallpaperService.desktopClock
                                        }
                                    }

                                    // slideshow
                                    Rectangle {
                                        implicitWidth: slideChipText.implicitWidth + 14
                                        implicitHeight: 16
                                        radius: 8
                                        color: WallpaperService.slideshowEnabled ? Qt.rgba(0.31, 0.98, 0.48, 0.12) : "transparent"
                                        border.width: 1
                                        border.color: WallpaperService.slideshowEnabled ? parent.on : parent.off

                                        Text {
                                            id: slideChipText
                                            anchors.centerIn: parent
                                            text: "slideshow"
                                            color: parent.border.color
                                            font { pixelSize: 8; letterSpacing: 0.5; family: "ZedMono Nerd Font" }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: WallpaperService.slideshowEnabled = !WallpaperService.slideshowEnabled
                                        }
                                    }

                                    // rotate favorites only
                                    Rectangle {
                                        implicitWidth: starChipText.implicitWidth + 14
                                        implicitHeight: 16
                                        radius: 8
                                        color: WallpaperService.rotationFavoritesOnly ? Qt.rgba(0.31, 0.98, 0.48, 0.12) : "transparent"
                                        border.width: 1
                                        border.color: WallpaperService.rotationFavoritesOnly ? parent.on : parent.off

                                        Text {
                                            id: starChipText
                                            anchors.centerIn: parent
                                            text: "\uf005 stars only"
                                            color: parent.border.color
                                            font { pixelSize: 8; letterSpacing: 0.5; family: "ZedMono Nerd Font" }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: WallpaperService.rotationFavoritesOnly = !WallpaperService.rotationFavoritesOnly
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }
                    }

                    // ── wallpaper grid ──
            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 3)
                cellHeight: 150
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
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 9

                        Image {
                            anchors.fill: parent
                            source: WallpaperService.thumbSource(cellWrap.path_, WallpaperService.thumbVersion)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize: { const s = 384; return Qt.size(s, s); }

                            // dim the current one slightly so the ring reads clearly
                            opacity: (cellWrap.path_ === WallpaperService.current && grid.currentIndex !== index) ? 0.85 : 1
                        }
                    }

                    // hover tint over the thumbnail
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 9
                        color: cellMa.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.10) : "transparent"
                    }

                    // border ring — always rendered above the thumbnail so
                    // the wallpaper image can never overlap the border
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 9
                        color: "transparent"
                        border.width: (grid.currentIndex === index || cellWrap.path_ === WallpaperService.current || cellMa.containsMouse) ? 2 : 1
                        border.color: grid.currentIndex === index
                            ? Themes.rofiAccent
                            : cellWrap.path_ === WallpaperService.current
                                ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.55)
                                : Qt.rgba(1, 1, 1, 0.12)
                    }

                    // "applied" corner badge on the current wallpaper
                    Rectangle {
                        visible: cellWrap.path_ === WallpaperService.current
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.topMargin: 5
                        anchors.leftMargin: 5
                        implicitWidth: 16
                        implicitHeight: 16
                        radius: 8
                        color: Themes.accent

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00c"
                            color: "#181825"
                            font { pixelSize: 8; bold: true; family: "Symbols Nerd Font Mono" }
                        }
                    }

                    MouseArea {
                        id: cellMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (!grid.moving)
                            grid.currentIndex = index
                        onClicked: root.applyWallpaper(cellWrap.path_)
                    }

                    // favorite star — top-right, above the click zone so it
                    // toggles the star without applying the wallpaper
                    Rectangle {
                        id: favBtn

                        readonly property bool fav: WallpaperService.isFavorite(cellWrap.path_)

                        visible: favFavMa.containsMouse || favBtn.fav
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 5
                        anchors.rightMargin: 5
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: 10
                        color: favFavMa.containsMouse || favBtn.fav ? Qt.rgba(0, 0, 0, 0.68) : Qt.rgba(0, 0, 0, 0.4)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.18)

                        Text {
                            anchors.centerIn: parent
                            text: favBtn.fav ? "\uf005" : "\uf006"
                            color: favBtn.fav ? "#ffb86c" : Themes.fg
                            font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
                        }

                        MouseArea {
                            id: favFavMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WallpaperService.toggleFavorite(cellWrap.path_)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: WallpaperService.wallpaperList.length === 0
                    text: "no wallpapers — drop images into ~/.config/quickshell/wallpapers"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                    font { pixelSize: 11; letterSpacing: 0.5; family: "ZedMono Nerd Font" }
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    width: parent.width - 24
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0 && WallpaperService.wallpaperList.length > 0
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