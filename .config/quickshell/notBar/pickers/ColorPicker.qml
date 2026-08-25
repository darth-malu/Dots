pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.themes

// Fully-featured color picker (dankmaterialshell-style):
// · SV gradient square + hue slider + opacity slider drive an HSV state model
// · screen eyedropper (hyprpicker) loads the pixel straight into the editor
// · HEX / RGB / HSL / HSV readouts, each one click from the clipboard
// · material palette + persisted recents load colors back into the editor
PanelWindow {
    id: root

    visible: PickerState.colorOpen && !picking
    implicitWidth: 320
    implicitHeight: col.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // ── HSV state model ──
    property real hue: 0.79
    property real sat: 0.55
    property real val: 0.98
    property real alpha: 1
    // SV-square cursor position (x = saturation, y = inverted value)
    property real gradX: sat
    property real gradY: 1 - val

    readonly property color currentColor: Qt.hsva(hue, sat, val, 1)
    // true while the eyedropper owns the screen — window hides but keeps state
    property bool picking: false

    function hexString(withAlpha) {
        const h = c => {
            let s = Math.round(c * 255).toString(16);
            return s.length < 2 ? "0" + s : s;
        };
        let out = "#" + h(currentColor.r) + h(currentColor.g) + h(currentColor.b);
        if (withAlpha && alpha < 1)
            out += h(alpha);
        return out;
    }

    function rgbString() {
        const r = Math.round(currentColor.r * 255);
        const g = Math.round(currentColor.g * 255);
        const b = Math.round(currentColor.b * 255);
        return alpha < 1 ? `rgba(${r}, ${g}, ${b}, ${Math.round(alpha * 255)})` : `rgb(${r}, ${g}, ${b})`;
    }

    function hslString() {
        const h = Math.round((currentColor.hslHue ?? 0) * 360);
        const s = Math.round((currentColor.hslSaturation ?? 0) * 100);
        const l = Math.round((currentColor.hslLightness ?? 0) * 100);
        return alpha < 1 ? `hsla(${h}, ${s}%, ${l}%, ${Math.round(alpha * 100)}%)` : `hsl(${h}, ${s}%, ${l}%)`;
    }

    function hsvString() {
        const h = Math.round(hue * 360);
        const s = Math.round(sat * 100);
        const v = Math.round(val * 100);
        return alpha < 1 ? `hsv(${h}, ${s}%, ${v}%, ${Math.round(alpha * 100)}%)` : `hsv(${h}, ${s}%, ${v}%)`;
    }

    // load any color into the editor (keeps hue stable for pure greys)
    function updateFromColor(c) {
        const nh = isNaN(c.hsvHue) ? hue : c.hsvHue;
        hue = nh;
        sat = isNaN(c.hsvSaturation) ? 0 : c.hsvSaturation;
        val = isNaN(c.hsvValue) ? 0 : c.hsvValue;
        alpha = c.a;
        gradX = sat;
        gradY = 1 - val;
        syncHexField();
    }

    function syncHexField() {
        if (!hexField.activeFocus)
            hexField.text = hexString(true);
    }

    function validHex(s) {
        return /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(s.trim());
    }

    function normalizeHex(s) {
        let t = s.trim();
        if (!t.startsWith("#"))
            t = "#" + t;
        return t.toLowerCase();
    }

    function copyText(text, label) {
        Quickshell.execDetached(["sh", "-c",
            `printf '%s' '${text}' | wl-copy && notify-send -a Color -t 1500 'copied ${label || text}'`]);
        PickerState.pushRecentColor(normalizeHex(hexString(true)));
    }

    function close() {
        PickerState.colorOpen = false;
    }

    onVisibleChanged: {
        if (visible)
            syncHexField();
    }

    // ── screen eyedropper — hyprpicker prints the picked hex ──
    Process {
        id: hyprpick

        command: ["sh", "-c", "hyprpicker"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.picking = false;
                const out = this.text.trim();
                if (root.validHex(out)) {
                    root.updateFromColor(Qt.color(root.normalizeHex(out)));
                    root.copyText(root.hexString(false));
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.close()
    }

    // ── horizontal slider used by hue + opacity tracks ──
    component TrackSlider: Item {
        id: ts

        property color solidColor: "transparent"
        property bool rainbow: false
        property real frac: 0
        signal dragged(real f)

        implicitHeight: 16

        // rainbow spectrum track
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 12
            radius: 6
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
            visible: ts.rainbow

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: "#ff0000" }
                GradientStop { position: 0.17; color: "#ffff00" }
                GradientStop { position: 0.33; color: "#00ff00" }
                GradientStop { position: 0.50; color: "#00ffff" }
                GradientStop { position: 0.67; color: "#0000ff" }
                GradientStop { position: 0.83; color: "#ff00ff" }
                GradientStop { position: 1.00; color: "#ff0000" }
            }
        }

        // fade-to-color track (opacity slider)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 12
            radius: 6
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
            visible: !ts.rainbow

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.rgba(ts.solidColor.r, ts.solidColor.g, ts.solidColor.b, 0)
                }
                GradientStop {
                    position: 1
                    color: ts.solidColor
                }
            }
        }

        Rectangle {
            id: knob

            width: 16
            height: 16
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: ts.frac * (parent.width - width)
            color: "transparent"
            border.width: 2
            border.color: "#f8f8f2"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: width / 2
                color: ts.rainbow ? Qt.hsva(ts.frac, 1, 1, 1) : ts.solidColor
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.5)
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => ts.dragged(Math.max(0, Math.min(1, mouse.x / width)))
            onPositionChanged: mouse => {
                if (pressed)
                    ts.dragged(Math.max(0, Math.min(1, mouse.x / width)));
            }
        }
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
            spacing: 9

            // ── header ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "\uf043"
                    color: Themes.rofiAccent
                    font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                }

                Item { Layout.fillWidth: true }

                // live preview chip
                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 22
                    radius: 6
                    color: root.currentColor
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.25)

                    Text {
                        visible: root.alpha < 1
                        anchors.centerIn: parent
                        text: Math.round(root.alpha * 100) + "%"
                        color: root.val > 0.5 ? "#282a36" : "#f8f8f2"
                        font { pixelSize: 9; bold: true; family: "ZedMono Nerd Font" }
                    }
                }

                Text {
                    text: "\uf00d"
                    color: closeMa.containsMouse ? "#ff5555" : "#6272a4"
                    font { pixelSize: 11; family: "Symbols Nerd Font Mono" }

                    MouseArea {
                        id: closeMa

                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // ── SV gradient area ──
            Rectangle {
                id: svArea

                Layout.fillWidth: true
                Layout.preferredHeight: 150
                radius: 8
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: Qt.hsva(root.hue, 1, 1, 1)

                    // white → pure hue (saturation axis)
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: "#ffffff"
                            }
                            GradientStop {
                                position: 1
                                color: "transparent"
                            }
                        }
                    }

                    // transparent → black (value axis)
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop {
                                position: 0
                                color: "transparent"
                            }
                            GradientStop {
                                position: 1
                                color: "#000000"
                            }
                        }
                    }
                }

                // draggable cursor ring
                Rectangle {
                    width: 14
                    height: 14
                    radius: width / 2
                    color: "transparent"
                    border.color: "white"
                    border.width: 2
                    x: root.gradX * parent.width - width / 2
                    y: root.gradY * parent.height - height / 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: parent.height - 4
                        radius: width / 2
                        color: "transparent"
                        border.color: "black"
                        border.width: 1
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    function apply(mouse) {
                        root.gradX = Math.max(0, Math.min(1, mouse.x / width));
                        root.gradY = Math.max(0, Math.min(1, mouse.y / height));
                        root.sat = root.gradX;
                        root.val = 1 - root.gradY;
                        root.syncHexField();
                    }
                    onPressed: mouse => apply(mouse)
                    onPositionChanged: mouse => {
                        if (pressed)
                            apply(mouse);
                    }
                }
            }

            // ── hue + opacity tracks ──
            TrackSlider {
                Layout.fillWidth: true
                rainbow: true
                frac: root.hue
                onDragged: f => {
                    root.hue = f;
                    root.syncHexField();
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TrackSlider {
                    id: alphaTrack

                    Layout.fillWidth: true
                    solidColor: root.currentColor
                    frac: root.alpha
                    onDragged: f => {
                        root.alpha = f;
                        root.syncHexField();
                    }
                }

                // eyedropper
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 22
                    radius: 6
                    color: eyeMa.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: eyeMa.containsMouse ? "#bd93f9" : Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: "\uf1fb"
                        color: "#bd93f9"
                        font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                    }

                    MouseArea {
                        id: eyeMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.picking = true;
                            hyprpick.running = true;
                        }
                    }
                }
            }

            // ── format readouts ──
            ColumnLayout {
                id: formats

                Layout.fillWidth: true
                spacing: 5

                component CopyButton: Rectangle {
                    id: cb

                    signal clicked()

                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 24
                    radius: 6
                    color: cbMa.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: cbMa.containsMouse ? "#bd93f9" : Qt.rgba(1, 1, 1, 0.12)

                    scale: cbMa.pressed ? 0.92 : 1

                    Behavior on scale {
                        NumberAnimation { duration: 80 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0c5"
                        color: cbMa.containsMouse ? "#e2d6fb" : "#8b93b8"
                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                    }

                    MouseArea {
                        id: cbMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cb.clicked()
                    }
                }

                component FormatRow: RowLayout {
                    id: fr

                    property string label
                    property string value

                    spacing: 7

                    Text {
                        text: fr.label
                        color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.55)
                        font { pixelSize: 8; letterSpacing: 1.5; bold: true; family: "ZedMono Nerd Font" }
                        Layout.preferredWidth: 30
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: fr.value
                            color: Themes.windowTextColor
                            font { pixelSize: 10; family: "ZedMono Nerd Font" }
                            elide: Text.ElideRight
                        }
                    }

                    CopyButton {
                        onClicked: root.copyText(fr.value)
                    }
                }

                // HEX gets an editable field; the rest are read-only rows
                RowLayout {
                    spacing: 7

                    Text {
                        text: "HEX"
                        color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.55)
                        font { pixelSize: 8; letterSpacing: 1.5; bold: true; family: "ZedMono Nerd Font" }
                        Layout.preferredWidth: 30
                    }

                    TextField {
                        id: hexField

                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        // text is managed imperatively by syncHexField() — a
                        // declarative binding here loops with onTextChanged
                        color: root.validHex(text) || text.length === 0 ? Themes.windowTextColor : "#ff5555"
                        font { pixelSize: 10; family: "ZedMono Nerd Font" }
                        selectByMouse: true
                        maximumLength: 9
                        verticalAlignment: TextInput.AlignVCenter
                        leftPadding: 8
                        rightPadding: 8
                        background: Rectangle {
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: hexField.activeFocus ? "#bd93f9" : Qt.rgba(1, 1, 1, 0.08)
                        }
                        onTextChanged: {
                            if (!activeFocus)
                                return;
                            if (root.validHex(text))
                                root.updateFromColor(Qt.color(root.normalizeHex(text)));
                        }
                        Keys.onReturnPressed: {
                            if (root.validHex(text)) {
                                root.copyText(root.normalizeHex(text));
                                focus = false;
                            }
                        }
                        Keys.onEnterPressed: {
                            if (root.validHex(text)) {
                                root.copyText(root.normalizeHex(text));
                                focus = false;
                            }
                        }
                        Keys.onEscapePressed: {
                            root.syncHexField();
                            focus = false;
                        }
                    }

                    CopyButton {
                        onClicked: root.copyText(root.hexString(root.alpha < 1))
                    }
                }

                FormatRow {
                    label: "RGB"
                    value: root.rgbString()
                }

                FormatRow {
                    label: "HSL"
                    value: root.hslString()
                }

                FormatRow {
                    label: "HSV"
                    value: root.hsvString()
                }
            }

            // ── copy shortcut button ──
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 8
                color: copyMa.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.22) : Qt.rgba(0.74, 0.58, 0.98, 0.1)
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.45)

                scale: copyMa.pressed ? 0.97 : 1

                Behavior on scale {
                    NumberAnimation { duration: 80 }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        text: "\uf0c5"
                        color: "#bd93f9"
                        font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                    }

                    Text {
                        text: "copy " + root.hexString(root.alpha < 1)
                        color: "#f8f8f2"
                        font { pixelSize: 11; bold: true; family: "Quicksand" }
                    }
                }

                MouseArea {
                    id: copyMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyText(root.hexString(root.alpha < 1))
                }
            }

            // ── material palette ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "MATERIAL COLORS"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.45)
                    font { pixelSize: 8; letterSpacing: 2; family: "ZedMono Nerd Font" }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 13
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: [
                            "#f44336", "#e91e63", "#9c27b0", "#673ab7", "#3f51b5", "#2196f3", "#03a9f4", "#00bcd4", "#009688", "#4caf50", "#8bc34a", "#cddc39", "#ffeb3b",
                            "#ffc107", "#ff9800", "#ff5722", "#795548", "#9e9e9e", "#607d8b", "#ffffff", "#000000",
                            "#d32f2f", "#c2185b", "#7b1fa2", "#512da8", "#303f9f", "#1976d2", "#0288d1", "#00796b", "#388e3c", "#689f38", "#afb42b", "#fbc02d", "#ffa000",
                            "#f57c00", "#e64a19", "#5d4037", "#757575", "#455a64", "#eceff1", "#e3f2fd",
                            "#c62828", "#ad1457", "#6a1b9a", "#4527a0", "#283593", "#1565c0", "#0277bd", "#00838f", "#00695c", "#2e7d32", "#558b2f", "#f9a825", "#ef6c00"
                        ]

                        delegate: Rectangle {
                            id: matSwatch

                            required property var modelData
                            required property int index

                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 4
                            color: modelData
                            border.width: matMa.containsMouse ? 2 : 1
                            border.color: matMa.containsMouse ? "#f8f8f2" : Qt.rgba(1, 1, 1, 0.14)

                            ToolTip.visible: matMa.containsMouse
                            ToolTip.delay: 350
                            ToolTip.text: modelData

                            MouseArea {
                                id: matMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.updateFromColor(Qt.color(matSwatch.modelData))
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

                            width: 21
                            height: 18
                            radius: 5
                            color: modelData
                            border.width: recentMa.containsMouse ? 2 : 1
                            border.color: recentMa.containsMouse ? "#f8f8f2" : Qt.rgba(1, 1, 1, 0.14)

                            ToolTip.visible: recentMa.containsMouse
                            ToolTip.delay: 350
                            ToolTip.text: modelData

                            MouseArea {
                                id: recentMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.updateFromColor(Qt.color(recentSwatch.modelData))
                            }
                        }
                    }
                }
            }
        }
    }
}
