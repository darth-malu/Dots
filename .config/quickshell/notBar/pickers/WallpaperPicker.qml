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

    // name-filtered dataset — favorites filter narrows to stars; light/dark are
    // opt-in toggles: click to filter that tone, unclick to widen back to all
    property bool favFilter: false
    property bool lightFilter: false
    property bool darkFilter: false

    readonly property bool filterActive: root.favFilter || root.lightFilter || root.darkFilter

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

    // apply stays open — Esc or the header close chip dismisses it
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

    // toggle pill for the banner — on = green filled, off = neutral pill;
    // hover hints so all three stay clearly legible over any wallpaper
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
            color: chip.on ? "#50fa7b"
                : chipMa.containsMouse ? Themes.fg : Qt.rgba(1, 1, 1, 0.55)
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

    // physical toggle for the light/dark banner toggle — a sliding switch
    // instead of a glyph-only chip; on = dark text (knob + label highlight)
    component ToneSwitch: RowLayout {
        id: toneSwitch

        property string label: ""
        property bool on: false
        signal toggled()

        spacing: 5
        Layout.alignment: Qt.AlignVCenter

        Text {
            text: toneSwitch.label
            color: toneSwitch.on
                ? "#50fa7b"
                : toneSwitchMa.containsMouse ? Themes.fg : Qt.rgba(1, 1, 1, 0.55)
            font { pixelSize: 8; letterSpacing: 0.5; family: "ZedMono Nerd Font" }

            Behavior on color { ColorAnimation { duration: 110 } }
        }

        Rectangle {
            id: track

            implicitWidth: 26
            implicitHeight: 14
            radius: 7
            color: toneSwitch.on
                ? Qt.rgba(0.31, 0.98, 0.48, 0.22)
                : toneSwitchMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
            border.color: toneSwitch.on ? "#50fa7b" : Qt.rgba(1, 1, 1, 0.25)

            Behavior on color { ColorAnimation { duration: 110 } }
            Behavior on border.color { ColorAnimation { duration: 110 } }

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: toneSwitch.on ? "#50fa7b" : Qt.rgba(1, 1, 1, 0.75)
                x: toneSwitch.on ? track.width - width - 2 : 2
                y: (track.height - height) / 2

                Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 110 } }
            }
        }

        MouseArea {
            id: toneSwitchMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toneSwitch.toggled()
        }
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

                // light opt-in filter — click filters to light, unclick shows all
                Rectangle {
                    visible: root.results.length > 0 || root.lightFilter
                    implicitWidth: lightChipText.implicitWidth + 14
                    implicitHeight: 16
                    radius: 8
                    color: root.lightFilter ? Qt.rgba(255, 237, 150, 0.14) : "transparent"
                    border.width: 1
                    border.color: root.lightFilter ? Qt.rgba(255, 237, 150, 0.7) : Themes.rofiBorder

                    Text {
                        id: lightChipText
                        anchors.centerIn: parent
                        text: "\uf185 light"
                        color: root.lightFilter ? "#ffedd6" : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.7)
                        font { pixelSize: 8; letterSpacing: 0.5; family: "ZedMono Nerd Font" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.lightFilter = !root.lightFilter
                    }
                }

                // dark opt-in filter — same semantics as the light chip
                Rectangle {
                    visible: root.results.length > 0 || root.darkFilter
                    implicitWidth: darkChipText.implicitWidth + 14
                    implicitHeight: 16
                    radius: 8
                    color: root.darkFilter ? Qt.rgba(130, 170, 255, 0.14) : "transparent"
                    border.width: 1
                    border.color: root.darkFilter ? Qt.rgba(130, 170, 255, 0.7) : Themes.rofiBorder

                    Text {
                        id: darkChipText
                        anchors.centerIn: parent
                        text: "\uf186 dark"
                        color: root.darkFilter ? "#aaccff" : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.7)
                        font { pixelSize: 8; letterSpacing: 0.5; family: "ZedMono Nerd Font" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.darkFilter = !root.darkFilter
                    }
                }

                // delete the focused wallpaper (shown only when one exists)
                Rectangle {
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

                // explicit close — apply no longer dismisses the picker
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
                        font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
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

                    // ── current wallpaper banner — rounded card carrying a
                    // live preview of the applied wallpaper ──
                    Rectangle {
                        id: currentBanner

                        Layout.fillWidth: true
                        Layout.preferredHeight: 82
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.045)
                        border.width: 1
                        border.color: Themes.rofiBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            // row 1 — rounded current picture + identity
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                // rounded container for the current wallpaper
                                Rectangle {
                                    id: curFrame

                                    Layout.preferredWidth: 108
                                    Layout.preferredHeight: 60
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

                                    // "live" badge — marks the applied wallpaper
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 4
                                        implicitWidth: liveTag.implicitWidth + 8
                                        implicitHeight: 13
                                        radius: 6.5
                                        color: Qt.rgba(0, 0, 0, 0.5)

                                        Text {
                                            id: liveTag
                                            anchors.centerIn: parent
                                            text: "\uf111 live"
                                            color: "#50fa7b"
                                            font { pixelSize: 6; letterSpacing: 0.8; family: "ZedMono Nerd Font" }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        text: "APPLIED"
                                        color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.4)
                                        font { pixelSize: 8; letterSpacing: 2; family: "ZedMono Nerd Font" }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: WallpaperService.current.length > 0 ? WallpaperService.current.split("/").pop() : "none"
                                        elide: Text.ElideMiddle
                                        color: Themes.fg
                                        font { pixelSize: 12; bold: true; family: "Quicksand" }
                                    }
                                }
                            }

                            // row 2 — automation chips + text-tone switches
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                WallChip {
                                    label: "\uf017 clock"
                                    on: WallpaperService.desktopClock
                                    onToggled: WallpaperService.desktopClock = !WallpaperService.desktopClock
                                }

                                WallChip {
                                    label: "slideshow"
                                    on: WallpaperService.slideshowEnabled
                                    onToggled: WallpaperService.slideshowEnabled = !WallpaperService.slideshowEnabled
                                }

                                WallChip {
                                    label: "\uf005 stars only"
                                    on: WallpaperService.rotationFavoritesOnly
                                    onToggled: WallpaperService.rotationFavoritesOnly = !WallpaperService.rotationFavoritesOnly
                                }

                                Item { Layout.fillWidth: true }

                                // desktop overlay text — flips the on-wall
                                // clock/notes ink light ↔ dark
                                ToneSwitch {
                                    label: WallpaperService.textTone === "dark" ? "dark text" : "light text"
                                    on: WallpaperService.textTone === "dark"
                                    onToggled: WallpaperService.textTone =
                                        WallpaperService.textTone === "light" ? "dark" : "light"
                                }

                                // bar-text tone — selects the wallpaper domain
                                // ("auto" follows the wallpaper, light/dark pin it)
                                ToneSwitch {
                                    label: WallpaperService.barTextTone === "light"
                                        ? "light wallpaper"
                                        : WallpaperService.barTextTone === "dark"
                                            ? "dark wallpaper"
                                            : "auto wallpaper"
                                    on: WallpaperService.barTextTone !== "auto"
                                    onToggled: WallpaperService.barTextTone =
                                        WallpaperService.barTextTone === "auto" ? "light" : "auto"
                                }
                            }
                        }
                    }

                    // hairline under the banner once the tinted bg is gone
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
                        // the wallpaper image can never overlap the border;
                        // constant width (no 1↔2px jump on hover = no blink);
                        // keyboard highlight uses a distinct color
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 9
                            color: "transparent"
                            border.width: 1
                            border.color: grid.currentIndex === index
                                ? Themes.pink
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

                    // favorite + tone assignment — top-right. The tone
                    // buttons only become visible when the STAR is hovered
                    // (never on plain tile hover); a wallpaper that is already
                    // assigned a tone shows that button lit permanently, like
                    // the favorite star.
                    Item {
                        id: toneCluster

                        readonly property string tone: WallpaperService.toneFor(cellWrap.path_)
                        readonly property bool revealHover: starHover.containsMouse || lightMa.containsMouse || darkMa.containsMouse
                        readonly property bool hasTag: favBtn.fav || toneCluster.tone !== "unknown"

                        // hidden on untouched, untagged tiles — reappears on hover
                        // or whenever the tile carries a favorite/tone tag
                        visible: cellMa.containsMouse || revealHover || toneCluster.hasTag

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
                                visible: toneCluster.revealHover || toneCluster.tone === "light"

                                implicitWidth: 22
                                implicitHeight: 18
                                radius: 9
                                color: toneCluster.tone === "light"
                                    ? Qt.rgba(255, 237, 150, 0.22)
                                    : Qt.rgba(0, 0, 0, 0.55)
                                border.width: 1
                                border.color: toneCluster.tone === "light"
                                    ? Qt.rgba(255, 237, 150, 0.7)
                                    : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf185"
                                    color: toneCluster.tone === "light"
                                        ? "#ffedd6"
                                        : Qt.rgba(1, 1, 1, 0.65)
                                    font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                                }

                                MouseArea {
                                    id: lightMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: WallpaperService.moveToTone(cellWrap.path_, "light")
                                }
                            }

                            // dark assign
                            Rectangle {
                                visible: toneCluster.revealHover || toneCluster.tone === "dark"

                                implicitWidth: 22
                                implicitHeight: 18
                                radius: 9
                                color: toneCluster.tone === "dark"
                                    ? Qt.rgba(130, 170, 255, 0.22)
                                    : Qt.rgba(0, 0, 0, 0.55)
                                border.width: 1
                                border.color: toneCluster.tone === "dark"
                                    ? Qt.rgba(130, 170, 255, 0.7)
                                    : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf186"
                                    color: toneCluster.tone === "dark"
                                        ? "#aaccff"
                                        : Qt.rgba(1, 1, 1, 0.65)
                                    font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                                }

                                MouseArea {
                                    id: darkMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
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
                    text: "no matches"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                    font { pixelSize: 11; letterSpacing: 1; family: "ZedMono Nerd Font" }
                }

                }

            // ── delete confirmation — the header trash opens it, Esc cancels ──
            Popup {
                id: confirmDel

                property string target: ""

                modal: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                // center over the picker once the content has been sized
                onOpened: {
                    confirmDel.x = Math.round((parent.width - confirmDel.width) / 2);
                    confirmDel.y = Math.round((parent.height - confirmDel.height) / 2);
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
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.close()
    }
}