pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick.Layouts
import qs.services
import qs.themes

// Right-clicking the bar opens this at the cursor (theme roster); left-click
// opens it in style mode (bar treatments). Single instance, switched by mode.
PopupWindow {
    id: root

    property var host
    property int mode: 0
    property bool menuOpen: false
    property real xPos: 6

    visible: root.menuOpen
    color: "transparent"
    grabFocus: false

    anchor.window: root.host
    anchor.rect.x: root.xPos
    anchor.rect.y: root.host.height + 8

    // 0 = color scheme roster, 1 = bar treatment roster
    readonly property var themeNames: ["Pyrple", "Gron", "Gruvbox", "Rose", "Everforest", "Soramane"]
    readonly property var styleNames: ["Transparent", "Solid Margin", "Solid", "Glass Margin", "Glass Full", "Glass Borderless"]
    readonly property string menuTitle: root.mode === 0 ? "color scheme" : "bar style"

    function openAt(m: int, gx: real): void {
        root.mode = m;
        const scrW = root.host?.screen?.width ?? 1920;
        root.xPos = Math.max(6, Math.min(gx, scrW - root.implicitWidth - 6));
        root.menuOpen = true;
    }

    function currentSel(): int {
        return root.mode === 0 ? MiscState.themeScheme : BarState.barMode;
    }

    function applySel(i: int): void {
        if (root.mode === 0)
            MiscState.themeScheme = i;
        else
            BarState.barMode = i;
        root.menuOpen = false;
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.menuOpen
        onActivated: root.menuOpen = false
    }

    implicitWidth: 200
    implicitHeight: menuColumn.implicitHeight

    Rectangle {
        id: menuCard
        anchors.fill: parent
        radius: 10
        color: Themes.popupCardBg
        border.width: 1
        border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.3)

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                text: (root.mode === 0 ? "\uf1fc " : "\uf2d1 ") + root.menuTitle
                color: Themes.muted
                font {
                    pixelSize: 9
                    letterSpacing: 0.5
                    family: "ZedMono Nerd Font"
                }
                Layout.leftMargin: 8
                Layout.topMargin: 2
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                height: 1
                color: Themes.separator
            }

            Repeater {
                id: rosterRepeater

                model: root.mode === 0 ? root.themeNames : root.styleNames

                delegate: Rectangle {
                    required property int index
                    required property string modelData

                    readonly property bool active: root.currentSel() === index
                    readonly property bool hovered: rowMa.containsMouse

                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 7
                    color: active ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.16) : hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 110
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: modelData
                            color: active ? Themes.fg : hovered ? Themes.dim : Themes.muted
                            font {
                                pixelSize: 11
                                bold: true
                                family: "Quicksand"
                            }
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: active
                            text: "\uf00c"
                            color: Themes.accent
                            font {
                                pixelSize: 9
                                bold: true
                                family: "Symbols Nerd Font Mono"
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applySel(index)
                    }
                }
            }
        }
    }
}
