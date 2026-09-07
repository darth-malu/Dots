import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.themes

BarBlock {
    id: disk
    underline: false

    required property var host

    property string mountPoint: "/"
    property string diskIcon: "\uf0a0"
    property string diskLabel: ""
    property bool showUsage: false

    property color colorLow: "#50fa7b"
    property color colorMid: Themes.pink
    property color colorHigh: Themes.accent2
    property color colorDanger: "#ff5555"
    property int dangerThreshold: 90

    // ── trash size / empty helpers ──
    property bool trashShow: false
    property var trashSizes: ({})
    property int trashTick: 0
    property string armedMount: ""

    readonly property int diskUsageValue: ResourcesState.diskUsagePercent
    readonly property string diskFigures: `${ResourcesState.diskUsed}/${ResourcesState.diskTotal}`

    readonly property color diskColor: {
        const v = diskUsageValue;
        if (v >= dangerThreshold)
            return colorDanger;
        if (v >= 60)
            return colorHigh;
        if (v >= 30)
            return colorMid;
        return colorLow;
    }

    readonly property var allDisksList: {
        var raw = ResourcesState.allDisks.trim();
        return raw.length > 0 ? raw.split("\n") : [];
    }

    // human bytes; "—" when empty, "…" while unknown
    function fmtSize(b) {
        if (b === undefined)
            return "…";
        if (b <= 0)
            return "—";
        if (b < 1024)
            return Math.round(b) + "B";
        if (b < 1048576)
            return (b / 1024).toFixed(0) + "K";
        if (b < 1073741824)
            return (b / 1048576).toFixed(1) + "M";
        return (b / 1073741824).toFixed(1) + "G";
    }

    // per-mount trash column value, "…" while the scan is running
    function trashSizeFor(mount) {
        return disk.fmtSize(disk.trashSizes[mount]);
    }

    // summed trash across every measured mount (rounded to a single unit)
    readonly property string trashTotal: {
        var t = 0;
        for (var m in disk.trashSizes) {
            if (disk.trashSizes[m] > 0)
                t += disk.trashSizes[m];
        }
        return disk.fmtSize(t);
    }

    // one sh pass measuring trash for every visible mount; each line is "mount<TAB>bytes"
    function computeTrash() {
        const scan = `while [ "$#" -gt 0 ]; do
  m="$1"; shift
  dirs=""
  case "$HOME" in
    "$m"/* | "$m") dirs="$HOME/.local/share/Trash" ;;
  esac
  dirs="$dirs $m/.Trash-$(id -u) $m/.Trash"
  sz=0
  for d in $dirs; do
    if [ -d "$d" ]; then
      b=$(du -sb "$d" 2>/dev/null | awk '{print $1}')
      [ -n "$b" ] && sz=$((sz + b))
    fi
  done
  printf '%s\t%s\n' "$m" "$sz"
done`;
        var mounts = [];
        var list = disk.allDisksList;
        for (var i = 0; i < list.length; i++) {
            var target = list[i].trim().split(/\s+/)[0];
            if (target && target.length > 0)
                mounts.push(target);
        }
        disk.trashTick++;
        trashCompute.tick = disk.trashTick;
        trashCompute.buf = "";
        trashCompute.command = ["sh", "-c", scan, "sh"].concat(mounts);
        trashCompute.running = true;
    }

    // candidates: $HOME/.local/share/Trash when home lives on this mount,
    // plus the classic top-level .Trash-<uid> / .Trash dirs
    function emptyTrashFor(mount) {
        if (!mount)
            return;
        const script = `m=${JSON.stringify(mount)}
dirs=""
case "$HOME" in
  "$m"/* | "$m") dirs="$HOME/.local/share/Trash" ;;
esac
dirs="$dirs $m/.Trash-$(id -u) $m/.Trash"
for d in $dirs; do
  rm -rf "$d" 2>/dev/null
done`;
        Quickshell.execDetached(["sh", "-c", script]);
        disk.computeTrash();
    }

    onLeftClicked: {
        allDisksPopup.visible = !allDisksPopup.visible;
        if (NasState.available)
            NasState.kickRecheck(1);
        if (disk.trashShow)
            disk.computeTrash();
        disk.armedMount = "";
    }
    onRightClicked: showUsage = !showUsage

    content: RowLayout {
        spacing: 4

        Canvas {
            id: gauge

            readonly property real progress: Math.min(disk.diskUsageValue / 100, 1)

            implicitWidth: 22
            implicitHeight: 22

            onProgressChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var cx = width / 2;
                var cy = height / 2;
                var r = cx - 2;
                var lw = 3;
                var startAngle = -Math.PI / 2;

                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.strokeStyle = "rgba(255, 255, 255, 0.06)";
                ctx.lineWidth = lw;
                ctx.stroke();

                if (progress > 0) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, startAngle, startAngle + Math.PI * 2 * Math.min(progress, 0.999));
                    ctx.strokeStyle = disk.diskColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }

                ctx.fillStyle = disk.diskColor;
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.font = `11px "Symbols Nerd Font Mono"`;
                ctx.fillText(disk.diskIcon, cx, cy + 0.5);
            }
        }

        BarText {
            id: usageText
            visible: disk.showUsage
            symbolText: disk.diskLabel.length > 0 ? disk.diskLabel : disk.diskFigures
            baseColor: disk.diskColor
            pointSize: 11
        }
    }

    PopupWindow {
        id: allDisksPopup
        visible: false
        grabFocus: true
        color: "transparent"

        anchor.window: disk.host
        anchor.rect.x: {
            let g = disk.mapToGlobal(0, 0);
            return g.x + (disk.width / 2) - (width / 2);
        }
        anchor.rect.y: 33

        implicitWidth: 420
        implicitHeight: allDisksCol.implicitHeight + 24

        Rectangle {
            anchors.fill: parent
            radius: 12
            layer.enabled: true
            layer.samples: 8
            color: Themes.popupCardBg
            border.width: 1
            border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.3)

            Shortcut {
                sequence: "Escape"
                onActivated: allDisksPopup.visible = false
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: allDisksPopup.visible = false
            }

            ColumnLayout {
                id: allDisksCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 0

                // ── NAS zone — per-share mount controls + unmounted tally ──
                ColumnLayout {
                    visible: NasState.available
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "\uf4a6"
                            color: NasState.allMounted ? "#50fa7b" : "#ffb86c"
                            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
                        }

                        Text {
                            text: "NAS"
                            color: Themes.fg
                            font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 1 }
                        }

                        Text {
                            readonly property int missing: NasState.unmountedCount
                            text: missing === 0 ? "all mounted" : `${missing} unmounted`
                            color: missing === 0 ? "#50fa7b" : "#ffb86c"
                            font { pixelSize: 9; bold: true; family: "Quicksand" }
                        }

                        Item { Layout.fillWidth: true }

                        // one-click remount of every missing share
                        Rectangle {
                            visible: NasState.unmountedCount > 0
                            implicitWidth: mountAllTxt.implicitWidth + 14
                            implicitHeight: 18
                            radius: 9
                            color: mountAllMa.containsMouse ? Qt.rgba(0.31, 0.98, 0.48, 0.15) : Themes.separator

                            Text {
                                id: mountAllTxt
                                anchors.centerIn: parent
                                text: "\ueb5b  mount all"
                                color: mountAllMa.containsMouse ? "#50fa7b" : Themes.dim
                                font { pixelSize: 9; bold: true; family: "Symbols Nerd Font Mono, Quicksand" }
                            }

                            MouseArea {
                                id: mountAllMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NasState.mountAll()
                            }
                        }
                    }

                    Repeater {
                        model: NasState.shares

                        Rectangle {
                            id: nasRow

                            required property var modelData

                            readonly property bool mounted: NasState.isMounted(nasRow.modelData)

                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 6
                            color: nasRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"

                            MouseArea {
                                id: nasRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 8

                                // live status dot
                                Rectangle {
                                    implicitWidth: 7
                                    implicitHeight: 7
                                    radius: 3.5
                                    color: nasRow.mounted ? "#50fa7b" : "#ff5555"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: nasRow.modelData.name
                                    color: Themes.fg
                                    font { pixelSize: 10; bold: true; family: "Quicksand" }
                                }

                                // mount / unmount action chip — fixed width so
                                // mount and unmount occupy identical footprints
                                Rectangle {
                                    implicitWidth: 78
                                    implicitHeight: 20
                                    radius: 9
                                    color: {
                                        if (!nasBtnMouse.containsMouse)
                                            return nasRow.mounted ? "transparent" : Themes.separator;
                                        return nasRow.mounted ? Qt.rgba(1, 0.33, 0.33, 0.15) : Qt.rgba(0.31, 0.98, 0.48, 0.15);
                                    }
                                    border.width: nasRow.mounted && !nasBtnMouse.containsMouse ? 1 : 0
                                    border.color: Qt.rgba(1, 1, 1, 0.12)

                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    Text {
                                        id: nasActionTxt
                                        anchors.centerIn: parent
                                        text: nasRow.mounted ? "\uf07c unmount" : "\ueb5b mount"
                                        color: {
                                            if (!nasBtnMouse.containsMouse)
                                                return nasRow.mounted ? Themes.dim : "#50fa7b";
                                            return nasRow.mounted ? "#ff5555" : "#50fa7b";
                                        }
                                        font { pixelSize: 9; bold: true; family: "Symbols Nerd Font Mono, Quicksand" }
                                    }

                                    MouseArea {
                                        id: nasBtnMouse
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: nasRow.mounted ? NasState.unmount(nasRow.modelData) : NasState.mount(nasRow.modelData)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                    }
                }

                // ── data zone — flat table straight on the popup, no recessed panel ──
                ColumnLayout {
                    id: mountZone
                    Layout.fillWidth: true
                    spacing: 4

                        // trash size option
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            spacing: 8

                            Rectangle {
                                id: trashToggle

                                implicitWidth: trashToggleTxt.implicitWidth + 18
                                implicitHeight: 18
                                radius: 9
                                color: trashToggleMa.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.15) : Themes.separator

                                Text {
                                    id: trashToggleTxt
                                    anchors.centerIn: parent
                                    text: disk.trashShow ? "\uf1f8  trash: on" : "\uf1f8  trash: off"
                                    color: disk.trashShow ? "#50fa7b" : Themes.dim
                                    font { pixelSize: 9; bold: true; family: "Symbols Nerd Font Mono, Quicksand" }
                                }

                                MouseArea {
                                    id: trashToggleMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        disk.trashShow = !disk.trashShow;
                                        if (disk.trashShow)
                                            disk.computeTrash();
                                    }
                                }
                            }

                            Rectangle {
                                visible: disk.trashShow
                                implicitWidth: trashRefreshTxt.implicitWidth + 18
                                implicitHeight: 18
                                radius: 9
                                color: trashRefreshMa.containsMouse ? Qt.rgba(0.31, 0.98, 0.48, 0.15) : Themes.separator

                                Text {
                                    id: trashRefreshTxt
                                    anchors.centerIn: parent
                                    text: "\uf021"
                                    color: trashRefreshMa.containsMouse ? "#50fa7b" : Themes.dim
                                    font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
                                }

                                MouseArea {
                                    id: trashRefreshMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: disk.computeTrash()
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                visible: disk.trashShow
                                text: disk.trashTotal + " total"
                                color: Themes.muted
                                font { pixelSize: 8; family: "ZedMono Nerd Font"; letterSpacing: 1 }
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                            }
                        }

                        // column labels — widths mirror the rows below:
                        // mount(140) · size(44) · free(44) · bar(fills) · use(32)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "mount"
                                color: Themes.muted
                                font {
                                    pixelSize: 9
                                    bold: true
                                    family: "Quicksand"
                                    letterSpacing: 1
                                }
                                Layout.preferredWidth: 140
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "size"
                                color: Themes.muted
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                                Layout.preferredWidth: 44
                                Layout.alignment: Qt.AlignRight
                            }

                            Text {
                                text: "free"
                                color: Themes.muted
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                                Layout.preferredWidth: 44
                                Layout.alignment: Qt.AlignRight
                            }

                            Text {
                                text: "trash"
                                color: disk.trashShow ? Themes.muted : Themes.borderMuted
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                                Layout.preferredWidth: 42
                                Layout.alignment: Qt.AlignRight
                            }

                            // spacer standing in for the usage-bar column
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                            }

                            Text {
                                text: "use"
                                color: Themes.muted
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                                Layout.preferredWidth: 32
                                Layout.alignment: Qt.AlignRight
                            }

                            Item {
                                Layout.preferredWidth: 38
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }

                        Repeater {
                            model: disk.allDisksList

                            Rectangle {
                                id: drow

                                required property string modelData

                                readonly property var parts: modelData.trim().split(/\s+/)
                                readonly property string mount: drow.parts.length >= 1 ? drow.parts[0] : ""
                                readonly property int pct: parts.length >= 5 ? parseInt(parts[4]) || 0 : 0
                                readonly property bool armed: disk.armedMount === drow.mount
                                readonly property bool hasTrash: (disk.trashSizes[drow.mount] ?? 0) > 0
                                // cpu-popup band palette for consistency
                                readonly property color tier: pct > 90 ? "#ff5555"
                                    : pct > 75 ? "#ffb86c"
                                    : pct > 60 ? "#50fa7b"
                                    : Themes.accent2

                                Layout.fillWidth: true
                                implicitHeight: 22
                                radius: 6
                                color: dmouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"

                                MouseArea {
                                    id: dmouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 6

                                    Text {
                                        Layout.preferredWidth: 140
                                        text: drow.parts[0] || ""
                                        color: Themes.fg
                                        font {
                                            pixelSize: 10
                                            family: "ZedMono Nerd Font"
                                        }
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        Layout.preferredWidth: 44
                                        horizontalAlignment: Text.AlignRight
                                        text: drow.parts[1] || ""
                                        color: Themes.muted
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 44
                                        horizontalAlignment: Text.AlignRight
                                        text: drow.parts[3] || ""
                                        color: Themes.dim
                                        font {
                                            pixelSize: 9
                                            family: "ZedMono Nerd Font"
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 42
                                        horizontalAlignment: Text.AlignRight
                                        text: disk.trashSizeFor(drow.mount)
                                        color: !disk.trashShow ? Themes.borderMuted : drow.hasTrash ? "#ffb86c" : Themes.borderMuted
                                        font {
                                            pixelSize: 9
                                            bold: drow.hasTrash
                                            family: "ZedMono Nerd Font"
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 5
                                        radius: 2.5
                                        color: Qt.rgba(1, 1, 1, 0.06)

                                        Rectangle {
                                            width: parent.width * Math.min(drow.pct / 100, 1)
                                            height: parent.height
                                            radius: 2.5
                                            color: Qt.rgba(drow.tier.r, drow.tier.g, drow.tier.b, 0.55)

                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 2
                                                radius: 1
                                                height: parent.height + 2
                                                visible: drow.pct > 3
                                                color: drow.tier
                                            }

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 32
                                        horizontalAlignment: Text.AlignRight
                                        text: `${drow.pct}%`
                                        color: drow.tier
                                        font {
                                            pixelSize: 9
                                            bold: true
                                            family: "ZedMono Nerd Font"
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 38
                                        implicitHeight: 16
                                        radius: 8
                                        color: !disk.trashShow ? "transparent"
                                            : dEmptyMa.containsMouse && drow.hasTrash ? (drow.armed ? Qt.rgba(1, 0.33, 0.33, 0.18) : Qt.rgba(1, 1, 1, 0.06)) : "transparent"
                                        border.width: disk.trashShow && drow.armed && drow.hasTrash ? 1 : 0
                                        border.color: Qt.rgba(1, 0.33, 0.33, 0.4)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf014"
                                            color: !disk.trashShow ? Themes.borderMuted : !drow.hasTrash ? Themes.borderMuted : drow.armed ? "#ff5555" : dEmptyMa.containsMouse ? Themes.fg : Themes.dim
                                            font { pixelSize: 8; bold: true; family: "Symbols Nerd Font Mono, Quicksand" }
                                        }

                                        // a fully armed row keeps the old double-click
                                        // shortcut; single-click arms for the banner
                                        MouseArea {
                                            id: dEmptyMa
                                            anchors.fill: parent
                                            anchors.margins: -5
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: disk.trashShow && drow.hasTrash
                                            onClicked: {
                                                if (drow.armed) {
                                                    const m = disk.armedMount;
                                                    disk.armedMount = "";
                                                    if (m)
                                                        disk.emptyTrashFor(m);
                                                } else {
                                                    disk.armedMount = drow.mount;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

Text {
                                text: "no mounts found"
                                color: Themes.muted
                                font {
                                    pixelSize: 10
                                    italic: true
                                    family: "Quicksand"
                                }
                                visible: disk.allDisksList.length === 0
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // ── trash confirm banner — slow fade instead of pop ──
                            Rectangle {
                                id: trashBanner

                                Layout.fillWidth: true
                                implicitHeight: 28
                                radius: 7
                                visible: disk.trashShow && disk.armedMount.length > 0
                                color: Qt.rgba(1, 0.33, 0.33, 0.1)
                                border.width: 1
                                border.color: Qt.rgba(1, 0.33, 0.33, 0.3)

                                opacity: disk.armedMount.length > 0 ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Empty trash on " + disk.armedMount + "?"
                                        color: Themes.fg
                                        font { pixelSize: 10; bold: true; family: "Quicksand" }
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "Cancel"
                                        color: Themes.muted
                                        font { pixelSize: 9; bold: true; family: "Quicksand" }
                                        TapHandler {
                                            gesturePolicy: TapHandler.ReleaseWithinBounds
                                            onTapped: disk.armedMount = ""
                                        }
                                    }

                                    Rectangle {
                                        implicitWidth: emptyBtnTxt.implicitWidth + 14
                                        implicitHeight: 20
                                        radius: 10
                                        color: "#ff5555"

                                        Text {
                                            id: emptyBtnTxt
                                            anchors.centerIn: parent
                                            text: "\uf014 Empty"
                                            color: Qt.rgba(0.04, 0.02, 0.08, 0.9)
                                            font { pixelSize: 9; bold: true; family: "Symbols Nerd Font Mono, Quicksand" }
                                        }

                                        TapHandler {
                                            gesturePolicy: TapHandler.ReleaseWithinBounds
                                            onTapped: {
                                                const m = disk.armedMount;
                                                disk.armedMount = "";
                                                if (m)
                                                    disk.emptyTrashFor(m);
                                            }
                                        }
                                    }
                                }
                            }
                }
            }
        }
    }

    Process {
        id: trashCompute
        property int tick: 0
        property string buf: ""

        stdout: SplitParser {
            onRead: data => trashCompute.buf += data
        }

        onExited: code => {
            if (trashCompute.tick !== disk.trashTick)
                return;
            var map = {};
            var lines = trashCompute.buf.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                if (line.length === 0)
                    continue;
                var tab = line.indexOf("\t");
                if (tab < 0)
                    continue;
                map[line.slice(0, tab)] = parseInt(line.slice(tab + 1), 10) || 0;
            }
            disk.trashSizes = map;
        }
    }
}