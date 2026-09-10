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
// · click applies · Esc closes
// · favorites/light/dark are opt-in filters grouped in one strip
// · the ring color swab tunes the hovered/selected tile border
// · the banner carries the live preview + slideshow toggle
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

    // name-filtered dataset — favorites filter narrows to stars; light/dark
    // are opt-in toggles: click to filter that tone, unclick to show all
    property bool favFilter: false
    property bool lightFilter: false
    property bool darkFilter: false

    // user-tuned ring color for the hovered/selected tile ("" falls back to
    // the theme pink, persisted via PickerState)
    readonly property color borderColor: PickerState.wallpaperBorder
        ? PickerState.wallpaperBorder
        : Themes.pink

    // "#aarrggbb" / "#rrggbb" color → uppercase 6-digit rgb for swatch compare
    function _hex6(c) {
        const s = String(c);
        const h = s.length >= 7 ? s.slice(s.length - 6) : s.slice(1);
        return h.toUpperCase();
    }

    function _toneMatch(p) {
        const t = WallpaperService.toneFor(p);
        return (root.lightFilter && t === "light") || (root.darkFilter && t === "dark");
    }

    readonly property var results: {
        var q = search.text.trim().toLowerCase();
        var list = WallpaperService.wallpaperList;
        if (root.favFilter)
            list = list.filter(p => WallpaperService.isFavorite(p));
        if (root.lightFilter || root.darkFilter)
            list = list.filter(p => root._toneMatch(p));
        if (q.length === 0)
            return list;
        return list.filter(p => p.toLowerCase().includes(q));
    }

    // applying stays open — Esc or the × dismisses
    function applyWallpaper(path) {
        if (!path || path.length === 0)
            return;
        WallpaperService.setWallpaper(path);
    }

    function close() {
        search.text = "";
        PickerState.wallpaperOpen = false;
    }

    // the wallpaper the header delete button acts on: the hovered/keyboard-
    // highlighted tile when there is one, otherwise the applied wallpaper
    function delTarget() {
        if (grid.currentItem && grid.currentItem.path_)
            return grid.currentItem.path_;
        return WallpaperService.current;
    }

    // toggle pill for the banner — on = green filled, off = neutral pill
    component WallChip: Rectangle {
        id: chip

        property string label: ""
        property bool on: false
        signal toggled()

        implicitWidth: chipText.implicitWidth + 16
        implicitHeight: 20
        radius: 10
        color: chip.on ? Qt.rgba(0.31, 0.98, 0.48, 0.15)
            : chipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: chip.on ? "#50fa7b"
            : chipMa.containsMouse ? Qt.rgba(0.31, 0.98, 0.48, 0.5) : Qt.rgba(1, 1, 1, 0.18)

        Behavior on color { ColorAnimation { duration: 110 } }
        Behavior on border.color { ColorAnimation { duration: 110 } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.on ? "#50fa7b"
                : chipMa.containsMouse ? Themes.fg : Qt.rgba(1, 1, 1, 0.55)
            font { pixelSize: 8; letterSpacing: 0.5; family: "ZedMono Nerd Font" }
        }

        MouseArea {
            id: chipMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: chip.toggled()
        }
    }

    // compact toggle pill for the header's search row — favorites / light / dark.
    // fixed 22px height + consistent padding: identical geometry whatever state,
    // so the pills can never drift, shift, or overlap each other
    component FilterPill: Rectangle {
        id: pill

        property string label: ""
        property bool on: false
        property color activeColor: "#ffffff"
        signal clicked()

        implicitWidth: pillText.implicitWidth + 18
        implicitHeight: 22
        radius: 11
        color: pill.on
            ? Qt.rgba(pill.activeColor.r, pill.activeColor.g, pill.activeColor.b, 0.2)
            : pillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: pill.on
            ? pill.activeColor
            : pillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.16)

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.on
                ? pill.activeColor
                : pillMa.containsMouse ? Themes.fg : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.8)
            font { pixelSize: 9; letterSpacing: 0.4; family: "ZedMono Nerd Font" }
        }

        MouseArea {
            id: pillMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: pill.clicked()
        }
    }

    // ── chrome ──
    Rectangle {
        id: chrome

        anchors.fill: parent
        radius: 10
        color: Themes.launcherBg
        border.width: 1
        border.color: Themes.rofiBorder

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header — icon + search + filter pills + count ──
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
                    Layout.preferredHeight: 24
                    leftPadding: 8
                    rightPadding: 8
                    color: Themes.windowTextColor
                    selectByMouse: true
                    placeholderText: ""
                    placeholderTextColor: "transparent"
                    background: Rectangle {
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Themes.separator
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

                FilterPill {
                    Layout.alignment: Qt.AlignVCenter
                    label: "\uf005 favorites"
                    on: root.favFilter
                    activeColor: "#50fa7b"
                    onClicked: root.favFilter = !root.favFilter
                }

                FilterPill {
                    Layout.alignment: Qt.AlignVCenter
                    label: "\uf185 light"
                    on: root.lightFilter
                    activeColor: "#ffedd6"
                    onClicked: root.lightFilter = !root.lightFilter
                }

                FilterPill {
                    Layout.alignment: Qt.AlignVCenter
                    label: "\uf186 dark"
                    on: root.darkFilter
                    activeColor: "#aaccff"
                    onClicked: root.darkFilter = !root.darkFilter
                }

                Text {
                    visible: root.results.length > 0
                    text: root.results.length
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.4)
                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                }
            }

            // ── current wallpaper banner — live preview + automation chips ──
            Rectangle {
                id: currentBanner

                Layout.fillWidth: true
                // rows: 8 (margin) + 52 (thumb) + 6 (spacing) + 20 (chips) + 8
                // (margin) = 94 — pinned to 96 so the chip row never touches the
                // banner edge / grid hairline again (the old exact-fit 94 let
                // sub-pixel rounding shove the slideshow/ring/delete buttons up
                // against the grid below = "buttons overlapping in the header")
                Layout.preferredHeight: 96
                Layout.minimumHeight: 96
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.045)
                border.width: 1
                border.color: Themes.rofiBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    // row 1 — rounded preview thumb + identity
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 52
                            radius: 10
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.14)
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: WallpaperService.current.length > 0
                                    ? WallpaperService.thumbSource(WallpaperService.current, WallpaperService.thumbVersion)
                                    : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: { const s = 192; return Qt.size(s, s); }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 3
                                implicitWidth: liveTag.implicitWidth + 6
                                implicitHeight: 12
                                radius: 6
                                color: Qt.rgba(0, 0, 0, 0.5)

                                Text {
                                    id: liveTag
                                    anchors.centerIn: parent
                                    text: "\uf111 live"
                                    color: "#50fa7b"
                                    font { pixelSize: 6; letterSpacing: 0.6; family: "ZedMono Nerd Font" }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: WallpaperService.current.length > 0 ? WallpaperService.current.split("/").pop() : "none"
                                elide: Text.ElideMiddle
                                color: Themes.fg
                                font { pixelSize: 12; bold: true; family: "Quicksand" }
                            }
                        }
                    }

                    // row 2 — slideshow + ring swab + delete
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        WallChip {
                            Layout.alignment: Qt.AlignVCenter
                            label: "slideshow"
                            on: WallpaperService.slideshowEnabled
                            onToggled: WallpaperService.slideshowEnabled = !WallpaperService.slideshowEnabled
                        }

                        Item { Layout.fillWidth: true }

                        // ring color swab — tunes the hovered/selected tile border
                        Rectangle {
                            id: ringSwab

                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: root.borderColor
                            border.width: 1
                            border.color: ringSwabMa.containsMouse ? Themes.rofiBorder : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf0c8"
                                color: Qt.rgba(0, 0, 0, 0.55)
                                font { pixelSize: 7; family: "Symbols Nerd Font Mono" }
                                visible: ringSwabMa.containsMouse
                            }

                            MouseArea {
                                id: ringSwabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ringPop.x = root._clampX(ringSwabMa.mapToItem(root, 0, ringSwabMa.height + 8).x, ringPop.implicitWidth);
                                    ringPop.y = Math.max(8, ringSwabMa.mapToItem(root, 0, 0).y + ringSwabMa.height + 8);
                                    ringPop.open();
                                }
                            }
                        }

                        // delete the focused wallpaper (shown only when one exists)
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            visible: root.delTarget().length > 0
                            implicitWidth: 18
                            implicitHeight: 18
                            radius: 9
                            color: delMa.containsMouse ? Qt.rgba(1, 0.4, 0.4, 0.16) : "transparent"
                            border.width: 1
                            border.color: delMa.containsMouse ? "#ff5555" : Themes.rofiBorder

                            Text {
                                anchors.centerIn: parent
                                text: "\uf2ed"
                                color: delMa.containsMouse ? "#ff5555" : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.7)
                                font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    confirmDel.target = root.delTarget();
                                    confirmDel.open();
                                }
                            }
                        }
                    }
                }
            }

            // hairline between the banner and the grid
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(1, 1, 1, 0.1)
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
                            sourceSize: { const s = 384; return Qt.size(s, s); }

                            opacity: (cellWrap.path_ === WallpaperService.current && grid.currentIndex !== index) ? 0.85 : 1
                        }
                    }

                    // hover tint
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 9
                        color: cellMa.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.10) : "transparent"
                    }

                    // border ring — always above the image, constant width
                    // (no 1↔2px hover jump = no blink); selected tile uses the
                    // user's ring color, applied wallpaper gets the accent
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 9
                        color: "transparent"
                        border.width: 1
                        border.color: grid.currentIndex === index
                            ? root.borderColor
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

                    // favorite + tone assignment — top-right. The tone buttons
                    // appear when the star (or the tile) is hovered; an already
                    // assigned tone keeps its button lit, like the star.
                    Item {
                        id: toneCluster

                        readonly property string tone: WallpaperService.toneFor(cellWrap.path_)
                        // keeping the tone buttons visible while the whole tile is
                        // hovered (not just the star) lets the cursor travel across
                        // the gap to a light/dark button without them vanishing
                        readonly property bool revealHover: cellMa.containsMouse || starHover.containsMouse || lightMa.containsMouse || darkMa.containsMouse
                        readonly property bool hasTag: favBtn.fav || toneCluster.tone !== "unknown"

                        // delay hiding so the cursor can travel from star → tone buttons
                        property bool revealDelayed: false
                        Timer {
                            id: revealTimer
                            interval: 300
                            onTriggered: toneCluster.revealDelayed = false
                        }

                        visible: cellMa.containsMouse || toneCluster.revealDelayed || toneCluster.hasTag

                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 5
                        anchors.rightMargin: 5
                        implicitWidth: toneRow.implicitWidth
                        implicitHeight: 22

                        Row {
                            id: toneRow

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            // light assign
                            Rectangle {
                                visible: toneCluster.revealHover || toneCluster.revealDelayed || toneCluster.tone === "light"

                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 9
                                color: "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf185"
                                    color: toneCluster.tone === "light"
                                        ? "#ffedd6"
                                        : Qt.rgba(1, 1, 1, 0.45)
                                    font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                                }

                                MouseArea {
                                    id: lightMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: { toneCluster.revealDelayed = true; revealTimer.stop(); }
                                    onExited: { revealTimer.restart(); }
                                    onClicked: WallpaperService.moveToTone(cellWrap.path_, "light")
                                }
                            }

                            // dark assign
                            Rectangle {
                                visible: toneCluster.revealHover || toneCluster.revealDelayed || toneCluster.tone === "dark"

                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 9
                                color: "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf186"
                                    color: toneCluster.tone === "dark"
                                        ? "#aaccff"
                                        : Qt.rgba(1, 1, 1, 0.45)
                                    font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                                }

                                MouseArea {
                                    id: darkMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: { toneCluster.revealDelayed = true; revealTimer.stop(); }
                                    onExited: { revealTimer.restart(); }
                                    onClicked: WallpaperService.moveToTone(cellWrap.path_, "dark")
                                }
                            }

                            // favorite star — its hover reveals the tone buttons
                            Item {
                                id: favBtn

                                readonly property bool fav: WallpaperService.isFavorite(cellWrap.path_)

                                implicitWidth: 22
                                implicitHeight: 22

                                Text {
                                    anchors.centerIn: parent
                                    text: favBtn.fav ? "\uf005" : "\uf006"
                                    color: favBtn.fav ? "#ffb86c" : (starHover.containsMouse ? "#ffb86c" : "white")
                                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                }

                                MouseArea {
                                    id: starHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: { toneCluster.revealDelayed = true; revealTimer.stop(); }
                                    onExited: { revealTimer.restart(); }
                                    onClicked: WallpaperService.toggleFavorite(cellWrap.path_)
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: WallpaperService.wallpaperList.length === 0
                    text: "no wallpapers — drop images into wallpapers/ or wallpapers/light/ + wallpapers/dark/"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                    font { pixelSize: 11; letterSpacing: 0.5; family: "ZedMono Nerd Font" }
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    width: parent.width - 24
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0 && WallpaperService.wallpaperList.length > 0
                    text: root.favFilter
                        ? (WallpaperService.favorites.length === 0
                            ? "no favorites yet — hover a tile and star it first"
                            : "no favorites match this filter")
                        : "no matches"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                    font { pixelSize: 11; letterSpacing: 1; family: "ZedMono Nerd Font" }
                }
            }
        }
    }

    // keep a popup fully inside the picker window
    function _clampX(x, w) {
        return Math.max(8, Math.min(x, root.width - w - 8));
    }

    // ── ring color palette — child of the chrome, not a layout, so it can
    // never disturb the header rows ──
    Popup {
        id: ringPop

        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            radius: 8
            color: Themes.cardBg
            border.width: 1
            border.color: Themes.borderColor
        }

        contentItem: ColumnLayout {
            spacing: 6

            Text {
                text: "ring color"
                color: Themes.muted
                font { pixelSize: 8; letterSpacing: 1; family: "ZedMono Nerd Font" }
            }

            GridLayout {
                columns: 4
                rows: 2
                columnSpacing: 8
                rowSpacing: 8

                ListModel {
                    id: ringColors

                    ListElement { col: "#f5c2e7" }
                    ListElement { col: "#89b4fa" }
                    ListElement { col: "#ff5555" }
                    ListElement { col: "#ffb86c" }
                    ListElement { col: "#f9e2af" }
                    ListElement { col: "#50fa7b" }
                    ListElement { col: "#94e2d5" }
                    ListElement { col: "#ffffff" }
                }

                Repeater {
                    model: ringColors

                    // delegate + required property (not an implicit delegate) —
                    // under pragma ComponentBehavior: Bound implicit delegates
                    // never get their model context in this runtime
                    delegate: Rectangle {
                        required property string col

                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        color: col
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.25)

                        Text {
                            anchors.centerIn: parent
                            visible: root._hex6(root.borderColor) === root._hex6(col)
                            text: "\uf00c"
                            color: Qt.rgba(1, 1, 1, 0.95)
                            font { pixelSize: 9; bold: true; family: "Symbols Nerd Font Mono" }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                PickerState.setWallpaperBorder(col);
                                ringPop.close();
                            }
                        }
                    }
                }
            }

            // reset to the theme default (PickerState pref cleared)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 18
                radius: 5
                color: resetMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "reset to theme default"
                    color: Themes.dim
                    font { pixelSize: 8; family: "Quicksand" }
                }

                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        PickerState.setWallpaperBorder("");
                        ringPop.close();
                    }
                }
            }
        }
    }

    // ── delete confirmation — the header trash opens it, Esc cancels ──
    Popup {
        id: confirmDel

        property string target: ""

        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: {
            confirmDel.x = Math.round((root.width - confirmDel.width) / 2);
            confirmDel.y = Math.round((root.height - confirmDel.height) / 2);
        }

        background: Rectangle {
            radius: 14
            color: Themes.cardBg
            border.width: 1
            border.color: Themes.borderColor
        }

        contentItem: ColumnLayout {
            spacing: 12
            implicitWidth: 280

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "\uf2ed"
                color: "#ff5555"
                font { pixelSize: 22; family: "Symbols Nerd Font Mono" }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "delete this wallpaper?"
                color: Themes.fg
                font { pixelSize: 13; bold: true; family: "Quicksand" }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: confirmDel.target.split("/").pop()
                elide: Text.ElideMiddle
                color: Themes.muted
                font { pixelSize: 10; family: "ZedMono Nerd Font" }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: cancelLbl.implicitWidth + 24
                    implicitHeight: 26
                    radius: 9
                    color: cancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: cancelMa.containsMouse ? Themes.borderColor : "transparent"

                    Text {
                        id: cancelLbl
                        anchors.centerIn: parent
                        text: "cancel"
                        color: Themes.mutedSoft
                        font { pixelSize: 10; family: "Quicksand" }
                    }

                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: confirmDel.close()
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: confirmLbl.implicitWidth + 24
                    implicitHeight: 26
                    radius: 9
                    color: confirmMa.containsMouse ? "#e63c3c" : "#ff5555"

                    Text {
                        id: confirmLbl
                        anchors.centerIn: parent
                        text: "delete"
                        color: "#1a1a1a"
                        font { pixelSize: 10; bold: true; family: "Quicksand" }
                    }

                    MouseArea {
                        id: confirmMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            WallpaperService.removeWallpaper(confirmDel.target);
                            confirmDel.target = "";
                            confirmDel.close();
                        }
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
}