pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._BackgroundEffect
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

    // frosted glass behind the panel (visible via the translucent launcherBg)
    BackgroundEffect.blurRegion: MiscState.rofiBlur ? panelBlur : null

    Region {
        id: panelBlur
        item: root.contentItem
        radius: Themes.rofiBlurRadius
    }

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
    readonly property color borderColor: PickerState.wallpaperBorder ? PickerState.wallpaperBorder : Themes.pink

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

    // toggle pill for the banner — on = green filled, off = neutral pill
    component WallChip: Rectangle {
        id: chip

        property string label: ""
        property bool on: false
        signal toggled

        implicitWidth: chipText.implicitWidth + 16
        implicitHeight: 20
        radius: 10
        color: chip.on ? Qt.rgba(0.31, 0.98, 0.48, 0.15) : chipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: chip.on ? "#50fa7b" : chipMa.containsMouse ? Qt.rgba(0.31, 0.98, 0.48, 0.5) : Qt.rgba(1, 1, 1, 0.18)

        Behavior on color {
            ColorAnimation {
                duration: 110
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 110
            }
        }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.on ? "#50fa7b" : chipMa.containsMouse ? Themes.fg : Qt.rgba(1, 1, 1, 0.55)
            font {
                pixelSize: 8
                letterSpacing: 0.5
                family: "ZedMono Nerd Font"
            }
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
        signal clicked

        implicitWidth: pillText.implicitWidth + 18
        implicitHeight: 22
        radius: 11
        color: pill.on ? Qt.rgba(pill.activeColor.r, pill.activeColor.g, pill.activeColor.b, 0.2) : pillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: pill.on ? pill.activeColor : pillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.16)

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.on ? pill.activeColor : pillMa.containsMouse ? Themes.fg : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.8)
            font {
                pixelSize: 9
                letterSpacing: 0.4
                family: "ZedMono Nerd Font"
            }
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

            // ── header — current wallpaper (thumb + name) on the left, search +
            // filter pills + count on the right, and the automation chips
            // (slideshow / ring swab) in a second row of the same card ──
            Rectangle {
                id: headerCard

                Layout.fillWidth: true
                // rows: 8 (margin) + 40 (thumb) + 6 (spacing) + 20 (chips) + 8
                // (margin) = 82 — pinned so the chip row never drifts into the
                // grid hairline below (sub-pixel rounding used to shove the
                // slideshow/ring buttons up into the grid = overlap bug)
                Layout.preferredHeight: 82
                Layout.minimumHeight: 82
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.045)
                border.width: 1
                border.color: Themes.rofiBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    // row 1 — thumb + name · search · filter pills · count
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // current wallpaper identity
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 40
                                radius: 8
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: WallpaperService.current.length > 0 ? WallpaperService.thumbSource(WallpaperService.current, WallpaperService.thumbVersion) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize: {
                                        const s = 120;
                                        return Qt.size(s, s);
                                    }
                                }
                            }

                            Text {
                                Layout.preferredWidth: 130
                                text: WallpaperService.current.length > 0 ? WallpaperService.current.split("/").pop() : "none"
                                elide: Text.ElideMiddle
                                color: Themes.fg
                                font {
                                    pixelSize: 12
                                    bold: true
                                    family: "Quicksand"
                                }
                            }
                        }

                        TextField {
                            id: search

                            Layout.alignment: Qt.AlignVCenter
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
                            font {
                                pixelSize: 10
                                family: "ZedMono Nerd Font"
                            }
                        }
                    }

                    // row 2 — slideshow chip + ring color swab
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        WallChip {
                            Layout.alignment: Qt.AlignVCenter
                            label: "slideshow"
                            on: WallpaperService.slideshowEnabled
                            onToggled: WallpaperService.slideshowEnabled = !WallpaperService.slideshowEnabled
                        }

                        Item {
                            Layout.fillWidth: true
                        }

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
                                font {
                                    pixelSize: 7
                                    family: "Symbols Nerd Font Mono"
                                }
                                visible: ringSwabMa.containsMouse
                            }

                            MouseArea {
                                id: ringSwabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ringPop.x = root._clampX(ringSwabMa.mapToItem(chrome, 0, ringSwabMa.height + 8).x, ringPop.implicitWidth);
                                    ringPop.y = Math.max(8, ringSwabMa.mapToItem(chrome, 0, 0).y + ringSwabMa.height + 8);
                                    ringPop.open();
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
                    property bool confirming: false

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 9

                        Image {
                            anchors.fill: parent
                            source: WallpaperService.thumbSource(cellWrap.path_, WallpaperService.thumbVersion)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: {
                                const s = 384;
                                return Qt.size(s, s);
                            }

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
                        border.color: grid.currentIndex === index ? root.borderColor : cellWrap.path_ === WallpaperService.current ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.55) : Qt.rgba(1, 1, 1, 0.12)
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
                            font {
                                pixelSize: 8
                                bold: true
                                family: "Symbols Nerd Font Mono"
                            }
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

                    // favorite star — top-right. Always visible once the
                    // wallpaper is starred; otherwise (like the tone cluster)
                    // it only surfaces when hovering this small corner region,
                    // never on hover over the whole wallpaper tile.
                    Item {
                        id: favCluster

                        readonly property bool fav: WallpaperService.isFavorite(cellWrap.path_)
                        property bool revealDelayed: false
                        Timer {
                            id: favTimer
                            interval: 300
                            onTriggered: favCluster.revealDelayed = false
                        }

                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 5
                        anchors.rightMargin: 5
                        implicitWidth: 22
                        implicitHeight: 22

                        // hover target: just this corner region, not the tile
                        // (the container itself stays hittable even while the
                        // glyph is hidden so entering this corner reveals it)
                        MouseArea {
                            id: favReveal
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                grid.currentIndex = index;
                                favCluster.revealDelayed = true;
                                favTimer.stop();
                            }
                            onExited: favTimer.restart()
                            onClicked: WallpaperService.toggleFavorite(cellWrap.path_)
                        }

                        Rectangle {
                            id: favBtn

                            visible: favCluster.fav || favCluster.revealDelayed
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 9
                            color: "transparent"
                            border.width: 0

                            Text {
                                anchors.centerIn: parent
                                text: favCluster.fav ? "\uf005" : "\uf006"
                                color: favCluster.fav ? "#ffb86c" : (starHover.containsMouse ? "#ffb86c" : Qt.rgba(1, 1, 1, 0.9))
                                font {
                                    pixelSize: 10
                                    family: "Symbols Nerd Font Mono"
                                }
                            }

                            MouseArea {
                                id: starHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: WallpaperService.toggleFavorite(cellWrap.path_)
                            }
                        }
                    }

                    // light/dark tone assignment — bottom-right. Unlike the
                    // star, these only surface when hovering this small corner
                    // region (not the whole tile); an already assigned tone
                    // keeps its button lit, like the star.
                    Item {
                        id: toneCluster

                        readonly property string tone: WallpaperService.toneFor(cellWrap.path_)
                        readonly property bool revealHover: toneReveal.containsMouse || lightMa.containsMouse || darkMa.containsMouse
                        property bool revealDelayed: false
                        Timer {
                            id: toneTimer
                            interval: 300
                            onTriggered: toneCluster.revealDelayed = false
                        }

                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 4
                        anchors.bottomMargin: 4
                        implicitWidth: 54
                        implicitHeight: 28

                        // hover target: just the corner region, not the tile
                        MouseArea {
                            id: toneReveal
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                grid.currentIndex = index;
                                toneCluster.revealDelayed = true;
                                toneTimer.stop();
                            }
                            onExited: toneTimer.restart()
                        }

                        Row {
                            id: toneRow

                            anchors.centerIn: parent
                            spacing: 3

                            // light assign
                            Rectangle {
                                visible: toneCluster.revealHover || toneCluster.revealDelayed || toneCluster.tone === "light"

                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 9
                                // translucent scrim so the glyphs stay readable
                                // over super-light wallpapers behind the tile
                                color: lightMa.containsMouse ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.35)
                                border.width: 1
                                border.color: lightMa.containsMouse ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.16)
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf185"
                                    color: toneCluster.tone === "light" ? "#ffedd6" : Qt.rgba(1, 1, 1, 0.85)
                                    font {
                                        pixelSize: 8
                                        family: "Symbols Nerd Font Mono"
                                    }
                                }

                                MouseArea {
                                    id: lightMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        toneCluster.revealDelayed = true;
                                        toneTimer.stop();
                                    }
                                    onExited: toneTimer.restart()
                                    onClicked: WallpaperService.moveToTone(cellWrap.path_, "light")
                                }
                            }

                            // dark assign
                            Rectangle {
                                visible: toneCluster.revealHover || toneCluster.revealDelayed || toneCluster.tone === "dark"

                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 9
                                color: darkMa.containsMouse ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.35)
                                border.width: 1
                                border.color: darkMa.containsMouse ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.16)
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf186"
                                    color: toneCluster.tone === "dark" ? "#aaccff" : Qt.rgba(1, 1, 1, 0.85)
                                    font {
                                        pixelSize: 8
                                        family: "Symbols Nerd Font Mono"
                                    }
                                }

                                MouseArea {
                                    id: darkMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        toneCluster.revealDelayed = true;
                                        toneTimer.stop();
                                    }
                                    onExited: toneTimer.restart()
                                    onClicked: WallpaperService.moveToTone(cellWrap.path_, "dark")
                                }
                            }
                        }
                    }

                    // ── delete — bottom-left; only surfaces when hovering this
                    // small corner region (mirrors favCluster), NOT the whole
                    // tile. Clicking arms a full-tile ✓/✗ confirmation. Plain
                    // glyph only (no pill, no border) ──
                    Item {
                        id: tileDelete

                        property bool revealDelayed: false
                        Timer {
                            id: delTimer
                            interval: 300
                            onTriggered: tileDelete.revealDelayed = false
                        }

                        readonly property bool revealed: deleteReveal.containsMouse || revealDelayed

                        visible: cellWrap.confirming || tileDelete.revealed
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 4
                        anchors.bottomMargin: 4
                        implicitWidth: 22
                        implicitHeight: 22

                        // glyph — rendered BELOW the reveal area so the
                        // MouseArea always receives hover without flicker
                        Rectangle {
                            id: delBtn
                            visible: tileDelete.revealed
                            anchors.fill: parent
                            radius: 9
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf1f8"
                                color: deleteReveal.containsMouse ? "#ff6666" : Qt.rgba(1, 1, 1, 0.85)
                                font {
                                    pixelSize: 11
                                    family: "Symbols Nerd Font Mono"
                                }
                            }
                        }

                        // hover + click target: declared LAST so it's on
                        // top — stable containsMouse, no mouse-steal flicker
                        MouseArea {
                            id: deleteReveal
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                grid.currentIndex = index;
                                tileDelete.revealDelayed = true;
                                delTimer.stop();
                            }
                            onExited: delTimer.restart()
                            onClicked: cellWrap.confirming = true
                        }
                    }

                    // confirmation overlay — covers the whole tile (volume-HUD
                    // style scrim) with a simple ✓ / ✗; no dialog popup
                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        visible: cellWrap.confirming
                        color: Qt.rgba(0, 0, 0, 0.6)
                        border.width: 1
                        border.color: "#ff5555"
                        z: 2

                        // clicking the scrim around the buttons cancels —
                        // declared BEFORE the buttons so their MouseAreas
                        // stay on top and receive the click
                        MouseArea {
                            anchors.fill: parent
                            onClicked: cellWrap.confirming = false
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: cellWrap.path_.split("/").pop()
                                elide: Text.ElideMiddle
                                Layout.maximumWidth: 130
                                width: 130
                                horizontalAlignment: Text.AlignHCenter
                                color: Qt.rgba(1, 1, 1, 0.85)
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                            }

                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                // confirm — deletes the file
                                Rectangle {
                                    implicitWidth: 34
                                    implicitHeight: 34
                                    radius: 17
                                    color: okMa.containsMouse ? "#6ee07a" : Qt.rgba(0, 0, 0, 0.45)
                                    border.width: 1
                                    border.color: okMa.containsMouse ? "#50fa7b" : Qt.rgba(1, 1, 1, 0.35)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf00c"
                                        color: okMa.containsMouse ? "#122414" : "#50fa7b"
                                        font {
                                            pixelSize: 13
                                            bold: true
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    MouseArea {
                                        id: okMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            WallpaperService.removeWallpaper(cellWrap.path_);
                                            cellWrap.confirming = false;
                                        }
                                    }
                                }

                                // cancel — closes the overlay
                                Rectangle {
                                    implicitWidth: 34
                                    implicitHeight: 34
                                    radius: 17
                                    color: noMa.containsMouse ? "#e05757" : Qt.rgba(0, 0, 0, 0.45)
                                    border.width: 1
                                    border.color: noMa.containsMouse ? "#ff5555" : Qt.rgba(1, 1, 1, 0.35)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf00d"
                                        color: noMa.containsMouse ? "#2a0e0e" : Qt.rgba(1, 1, 1, 0.9)
                                        font {
                                            pixelSize: 13
                                            bold: true
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    MouseArea {
                                        id: noMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: cellWrap.confirming = false
                                    }
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
                    visible: root.results.length === 0 && WallpaperService.wallpaperList.length > 0
                    text: root.favFilter ? (WallpaperService.favorites.length === 0 ? "no favorites yet — hover a tile and star it first" : "no favorites match this filter") : "no matches"
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
                font {
                    pixelSize: 8
                    letterSpacing: 1
                    family: "ZedMono Nerd Font"
                }
            }

            GridLayout {
                columns: 4
                rows: 2
                columnSpacing: 8
                rowSpacing: 8

                ListModel {
                    id: ringColors

                    ListElement {
                        col: "#f5c2e7"
                    }
                    ListElement {
                        col: "#89b4fa"
                    }
                    ListElement {
                        col: "#ff5555"
                    }
                    ListElement {
                        col: "#ffb86c"
                    }
                    ListElement {
                        col: "#f9e2af"
                    }
                    ListElement {
                        col: "#50fa7b"
                    }
                    ListElement {
                        col: "#94e2d5"
                    }
                    ListElement {
                        col: "#ffffff"
                    }
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
                            font {
                                pixelSize: 9
                                bold: true
                                family: "Symbols Nerd Font Mono"
                            }
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
                    font {
                        pixelSize: 8
                        family: "Quicksand"
                    }
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

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: {
            // an armed ✓/✗ overlay takes Esc before the whole picker closes
            const kids = grid.contentItem?.children ?? [];
            for (let i = 0; i < kids.length; i++) {
                if (kids[i].confirming) {
                    kids[i].confirming = false;
                    return;
                }
            }
            root.close();
        }
    }
}
