pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.themes

// Color picker — two ways to grab a color:
// · "pick from screen" → hyprpicker (pixel-accurate eyedropper)
// · built-in swatch palette + hex entry for composing colors offline
// Everything lands on the clipboard; picks land in the recents strip.
PanelWindow {
    id: root

    visible: PickerState.colorOpen
    implicitWidth: 320
    implicitHeight: col.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string draftHex: "#bd93f9"

    // curated dracula-family starting points
    readonly property var palette: [
        "#bd93f9", "#8be9fd", "#50fa7b", "#ffb86c", "#ff79c6", "#ff5555",
        "#f1fa8c", "#6272a4", "#f8f8f2", "#282a36", "#e06c75", "#56b6c2",
        "#98c379", "#d19a66", "#c678dd", "#61afef"
    ]

    function validHex(s) {
        return /^#?[0-9a-fA-F]{6}$/.test(s.trim());
    }

    function normalizeHex(s) {
        let t = s.trim();
        if (!t.startsWith("#"))
            t = "#" + t;
        return t.toLowerCase();
    }

    function copyColor(hex) {
        const c = normalizeHex(hex);
        PickerState.pushRecentColor(c);
        Quickshell.execDetached(["sh", "-c",
            `printf '%s' '${c}' | wl-copy && notify-send -a Color -t 1500 'copied ${c}'`]);
    }

    function close() {
        hexField.text = "";
        PickerState.colorOpen = false;
    }

    onVisibleChanged: {
        if (visible)
            hexField.forceActiveFocus();
    }

    // screen eyedropper — hyprpicker prints the picked hex
    Process {
        id: hyprpick

        command: ["sh", "-c", "hyprpicker"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                if (root.validHex(out)) {
                    root.draftHex = root.normalizeHex(out);
                    root.copyColor(root.draftHex);
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.close()
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Themes.launcherBg
        border.width: 1
        border.color: Themes.rofiBorder

        ColumnLayout {
            id: col

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            // ── header ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "\uf043"
                    color: Themes.rofiAccent
                    font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                }

                Text {
                    text: "color picker"
                    color: Themes.windowTextColor
                    font { pixelSize: 12; bold: true; family: "Quicksand" }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.draftHex
                    color: "#282a36"
                    font { pixelSize: 11; bold: true; family: "ZedMono Nerd Font" }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -5
                        radius: 6
                        z: -1
                        color: root.draftHex
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(Themes.rofiBorder.r, Themes.rofiBorder.g, Themes.rofiBorder.b, 0.35)
            }

            // ── screen pick button ──
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 8
                color: eyeMa.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.16) : Qt.rgba(0.74, 0.58, 0.98, 0.08)
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.4)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "\uf047"
                        color: "#bd93f9"
                        font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
                    }

                    Text {
                        text: "pick from screen"
                        color: "#f8f8f2"
                        font { pixelSize: 11; bold: true; family: "Quicksand" }
                    }
                }

                MouseArea {
                    id: eyeMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.close();
                        hyprpick.running = true;
                    }
                }
            }

            // ── hex entry ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: hexField

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    placeholderText: "#rrggbb"
                    placeholderTextColor: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                    color: root.validHex(text) || text.length === 0 ? Themes.windowTextColor : "#ff5555"
                    font { pixelSize: 12; family: "ZedMono Nerd Font" }
                    selectByMouse: true
                    maximumLength: 7
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: 8
                    rightPadding: 8
                    background: Rectangle {
                        radius: 7
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: hexField.activeFocus ? "#bd93f9" : Qt.rgba(Themes.rofiBorder.r, Themes.rofiBorder.g, Themes.rofiBorder.b, 0.3)
                    }
                    onTextChanged: if (root.validHex(text))
                        root.draftHex = root.normalizeHex(text)
                    Keys.onReturnPressed: {
                        if (root.validHex(text)) {
                            root.copyColor(text);
                            root.close();
                        }
                    }
                    Keys.onEnterPressed: {
                        if (root.validHex(text)) {
                            root.copyColor(text);
                            root.close();
                        }
                    }
                    Keys.onEscapePressed: root.close()
                }

                Rectangle {
                    implicitWidth: 44
                    implicitHeight: 30
                    radius: 7
                    color: root.validHex(root.draftHex) ? root.draftHex : "transparent"
                    border.width: 1
                    border.color: copyMa.containsMouse ? "#bd93f9" : Qt.rgba(1, 1, 1, 0.2)

                    Text {
                        visible: !copyMa.containsMouse
                        anchors.centerIn: parent
                        text: "\uf0c5"
                        color: "#f8f8f2"
                        font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                    }

                    Text {
                        visible: copyMa.containsMouse
                        anchors.centerIn: parent
                        text: "copy"
                        color: "#bd93f9"
                        font { pixelSize: 9; bold: true; family: "Quicksand" }
                    }

                    MouseArea {
                        id: copyMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.validHex(root.draftHex)) {
                                root.copyColor(root.draftHex);
                                root.close();
                            }
                        }
                    }
                }
            }

            // ── palette grid ──
            GridLayout {
                Layout.fillWidth: true
                columns: 8
                columnSpacing: 5
                rowSpacing: 5

                Repeater {
                    model: root.palette

                    delegate: Rectangle {
                        id: swatch

                        required property var modelData
                        required property int index

                        Layout.preferredWidth: 31
                        Layout.preferredHeight: 26
                        radius: 6
                        color: modelData
                        border.width: swMa.containsMouse ? 2 : 1
                        border.color: swMa.containsMouse ? "#f8f8f2" : Qt.rgba(1, 1, 1, 0.15)

                        Behavior on border.width {
                            NumberAnimation { duration: 80 }
                        }

                        MouseArea {
                            id: swMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.draftHex = swatch.modelData;
                                root.copyColor(swatch.modelData);
                                root.close();
                            }
                        }
                    }
                }
            }

            // ── recents strip ──
            ColumnLayout {
                visible: PickerState.recentColors.length > 0
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "RECENT"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.45)
                    font { pixelSize: 8; letterSpacing: 2; family: "ZedMono Nerd Font" }
                }

                RowLayout {
                    spacing: 4

                    Repeater {
                        model: PickerState.recentColors.slice(0, 12)

                        delegate: Rectangle {
                            id: recentSwatch

                            required property var modelData

                            width: 22
                            height: 18
                            radius: 5
                            color: modelData
                            border.width: recentMa.containsMouse ? 2 : 1
                            border.color: recentMa.containsMouse ? "#f8f8f2" : Qt.rgba(1, 1, 1, 0.15)

                            ToolTip.visible: recentMa.containsMouse
                            ToolTip.delay: 400
                            ToolTip.text: modelData

                            MouseArea {
                                id: recentMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.draftHex = recentSwatch.modelData;
                                    root.copyColor(recentSwatch.modelData);
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "\u21b5 copy hex \u00b7 click swatch copy \u00b7 esc close"
                color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.3)
                font { pixelSize: 9; letterSpacing: 2; family: "ZedMono Nerd Font" }
            }
        }
    }
}
