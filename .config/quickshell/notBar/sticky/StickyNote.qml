pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.themes

// A single sticky note — a desktop-level surface (above the wallpaper, below
// the bar / windows) that can be dragged by its title strip and resized via
// the bottom-right handle. Positions are stored as 0..1 screen fractions so
// they survive resolution changes; text lives in the NotesState model.
PanelWindow {
    id: root

    required property int index

    screen: Quickshell.primaryScreen
    visible: WallpaperService.enabled && (root.row?.visible ?? false)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-sticky"

    // PanelWindow positions via anchors + margins (no x/y) — hold pixel
    // coords in px/py and bind margins to them so drags just mutate the props.
    anchors.top: true
    anchors.left: true
    margins.top: root.py
    margins.left: root.px

    // ---- helpers (model-backed; index changes rewires by value) ----
    function row() {
        if (root.index < 0 || root.index >= notesModel.count)
            return null;
        return notesModel.get(root.index);
    }

    function initX() {
        const s = root.screen;
        return s ? Math.round(((root.row()?.x ?? 0.3)) * s.width) : 300;
    }
    function initY() {
        const s = root.screen;
        return s ? Math.round((root.row()?.y ?? 0.25) * s.height) : 200;
    }

    property real px: root.initX()
    property real py: root.initY()

    // record the model row at creation so later re-evaluations (a different
    // note sharing this delegate index) don't mutate the wrong row
    readonly property string noteId: root.row()?.id ?? ""

    // colors — a small palette; 0 = accent-tinted base
    readonly property var palette: [
        { accent: "#ffb86c", name: "amber" },
        { accent: "#8be9fd", name: "cyan" },
        { accent: "#ff79c6", name: "pink" },
        { accent: "#50fa7b", name: "green" },
        { accent: "#bd93f9", name: "purple" }
    ]

    readonly property color noteAccent: palette[(root.row()?.color ?? 0) % palette.length].accent

    implicitWidth: root.row()?.w ?? 240
    implicitHeight: root.row()?.h ?? 160

    // persist position/size back into the model (as fractions)
    function commitPos() {
        const s = root.screen;
        if (!s)
            return;
        const idx = root.indexOf(root.noteId);
        if (idx >= 0)
            NotesState.setPos(idx, Math.max(0, Math.min(1, root.px / s.width)), Math.max(0, Math.min(1, root.py / s.height)));
    }
    function commitSize() {
        const idx = root.indexOf(root.noteId);
        if (idx >= 0)
            NotesState.setSize(idx, Math.max(180, Math.round(root.width)), Math.max(100, Math.round(root.height)));
    }

    function indexOf(id) {
        for (let i = 0; i < notesModel.count; i++)
            if (notesModel.get(i).id === id)
                return i;
        return -1;
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.rgba(0.07, 0.05, 0.1, 0.88)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        // colored top strip identifying the palette tone
        Rectangle {
            height: 3
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            radius: 2
            color: root.noteAccent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Text {
                id: dateLbl
                Layout.alignment: Qt.AlignLeft
                text: "sticky"
                color: root.noteAccent
                font { pixelSize: 8; letterSpacing: 1; family: "ZedMono Nerd Font"; bold: true }
            }

            TextArea {
                id: noteTextArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.row()?.text ?? ""
                color: "#f2f2f7"
                font { pixelSize: 11; family: "Quicksand" }
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                background: Rectangle {
                    color: "transparent"
                    radius: 4
                    border.width: 1
                    border.color: "#ffffff22"
                }
                padding: 6

                onEditingFinished: {
                    const idx = root.indexOf(root.noteId);
                    if (idx >= 0)
                        NotesState.setText(idx, noteTextArea.text);
                }
            }

            // title strip = drag handle + palette cycle + delete
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 16
                    radius: 4
                    color: dragMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    border.width: 1
                    border.color: dragMa.pressed ? root.noteAccent : Qt.rgba(1, 1, 1, 0.06)
                }

                Rectangle {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 4
                    color: colorMa.containsMouse
                        ? Qt.rgba(root.noteAccent.r, root.noteAccent.g, root.noteAccent.b, 0.25)
                        : Qt.rgba(1, 1, 1, 0.05)
                    Text {
                        anchors.centerIn: parent
                        text: "\uf031"
                        color: root.noteAccent
                        font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                    }
                    MouseArea {
                        id: colorMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const idx = root.indexOf(root.noteId);
                            if (idx >= 0)
                                NotesState.setColor(idx, ((root.row()?.color ?? 0) + 1) % root.palette.length);
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 4
                    color: delMa.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.18) : Qt.rgba(1, 1, 1, 0.05)
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
                        onClicked: NotesState.removeById(root.noteId)
                    }
                }
            }
        }

        // overlays: drag strip + resize handle
        MouseArea {
            id: dragMa
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.right: parent.right
            height: 22
            cursorShape: Qt.SizeAllCursor
            property real sx: 0
            property real sy: 0

            onPressed: {
                dragMa.sx = mouse.x;
                dragMa.sy = mouse.y;
            }
            onPositionChanged: {
                if (!pressed)
                    return;
                root.px = Math.max(0, root.px + (mouse.x - dragMa.sx));
                root.py = Math.max(0, root.py + (mouse.y - dragMa.sy));
            }
            onReleased: root.commitPos()
        }

        Item {
            width: 14
            height: 14
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 2

            MouseArea {
                id: resizeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor
                property real sx: 0
                property real sy: 0

                onPressed: {
                    resizeMa.sx = mouse.x;
                    resizeMa.sy = mouse.y;
                }
                onPositionChanged: {
                    if (!pressed)
                        return;
                    root.width = Math.max(180, root.width + (mouse.x - resizeMa.sx));
                    root.height = Math.max(100, root.height + (mouse.y - resizeMa.sy));
                }
                onReleased: root.commitSize()
            }
        }
    }
}