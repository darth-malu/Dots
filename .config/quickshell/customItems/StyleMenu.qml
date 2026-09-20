pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick.Layouts
import qs.services
import qs.themes

// Right-clicking the bar opens this at the cursor (theme roster); left-click
// opens it in style mode (bar treatments); alt-click in workspace mode
// (dots / numbers / icons). Single instance, switched by mode.
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

    // 0 = color scheme roster, 1 = bar treatment roster, 2 = workspace flavour
    readonly property var themeNames: ["Pyrple", "Gron", "Gruvbox", "Rose", "Everforest", "Bleu"]
    readonly property var styleNames: ["Transparent", "Solid +", "Solid", "Glass +", "Glass", "Glass !border"]
    readonly property var workspaceNames: ["Dots", "Workspaces", "Workspaces + icons"]
    readonly property string menuTitle: root.mode === 0 ? "Color Scheme" : root.mode === 1 ? "Bar Style" : "Workspaces"
    readonly property var rosterNames: root.mode === 0 ? root.themeNames : root.mode === 1 ? root.styleNames : root.workspaceNames

    function openAt(m: int, gx: real): void {
        // clicking the same bar button again toggles the popup closed
        if (root.menuOpen && root.mode === m) {
            root.menuOpen = false;
            return;
        }
        root.mode = m;
        const scrW = root.host?.screen?.width ?? 1920;
        root.xPos = Math.max(6, Math.min(gx, scrW - root.implicitWidth - 6));
        root.menuOpen = true;
    }

    function currentSel(): int {
        return root.mode === 0 ? MiscState.themeScheme
            : root.mode === 1 ? BarState.barMode
            : MiscState.workspaceStyle;
    }

    function applySel(i: int): void {
        if (root.mode === 0)
            MiscState.themeScheme = i;
        else if (root.mode === 1)
            BarState.barMode = i;
        else
            MiscState.workspaceStyle = i;
        root.menuOpen = false;
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.menuOpen
        onActivated: root.menuOpen = false
    }

    implicitWidth: 150
    implicitHeight: menuColumn.implicitHeight + 14

    Rectangle {
        id: menuCard
        anchors.fill: parent
        radius: 10
        color: Themes.popupCardBg
        border.width: 2
        border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.3)

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            anchors.topMargin: 2
            anchors.bottomMargin: 4
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                spacing: 8

                Rectangle {
                    // implicitWidth: 24
                    // implicitHeight: 24
                    implicitWidth: modeIcon.width
                    implicitHeight: modeIcon.height
                    radius: 6
                    // color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.15)
                    color: 'transparent'
                    border.width: 0
                    border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.35)

                    Text {
                        id: modeIcon
                        anchors.centerIn: parent
                        text: root.mode === 0 ? "" : root.mode === 1 ? "" : "󰇘"
                        color: Themes.accent
                        font {
                            pixelSize: 11
                            family: "Symbols Nerd Font Mono"
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 1

                    Text {
                        text: root.menuTitle
                        color: Themes.fg
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "Quicksand"
                    }

                    Text {
                        visible: false
                        text: "currently " + root.rosterNames[root.currentSel()]
                        color: Themes.muted
                        font {
                            pixelSize: 9
                            family: "Quicksand"
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.3
                        color: Themes.separator
                    }
                    GradientStop {
                        position: 0.7
                        color: Themes.separator
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            Repeater {
                id: rosterRepeater

                model: root.rosterNames

                delegate: Rectangle {
                    required property int index
                    required property string modelData

                    readonly property bool active: root.currentSel() === index
                    readonly property bool hovered: rowMa.containsMouse

                    Layout.fillWidth: true
                    Layout.bottomMargin: 0
                    implicitHeight: 24
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
