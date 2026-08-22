import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services

// Standalone OSD pill (mirrors the volume OSD look) that pops under the bar
// whenever brightness changes, tinted by level.
PopupWindow {
    id: osd

    required property var barWindow

    // warm = dim · yellow = mid · green = bright (same scheme as wifi signal)
    readonly property color accent: BrightnessState.pctDisplay <= 33 ? "#ffb86c"
        : BrightnessState.pctDisplay <= 66 ? "#f1fa8c"
        : "#50fa7b"

    property bool shown: false

    anchor.window: barWindow
    anchor.rect.x: Math.round((barWindow?.width ?? 0) / 2 - width / 2)
    anchor.rect.y: 33
    implicitWidth: pillRow.implicitWidth + 26
    implicitHeight: 28
    color: "transparent"
    visible: osd.shown

    function bump() {
        osd.shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer

        interval: 900
        onTriggered: osd.shown = false
    }

    Connections {
        target: BrightnessState

        function onLevelChanged() {
            osd.bump();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.72)
        border.width: 1
        border.color: Qt.rgba(osd.accent.r, osd.accent.g, osd.accent.b, 0.35)

        RowLayout {
            id: pillRow

            anchors.centerIn: parent
            spacing: 6

            Text {
                text: BrightnessState.pctDisplay <= 15 ? "\uf186" : "\uf185"
                color: osd.accent
                font {
                    pixelSize: 13
                    family: "Symbols Nerd Font Mono"
                }
            }

            Text {
                text: BrightnessState.pctDisplay + "%"
                color: "#f8f8f2"
                font {
                    pixelSize: 12
                    bold: true
                    family: "ZedMono Nerd Font"
                }
            }
        }
    }
}
