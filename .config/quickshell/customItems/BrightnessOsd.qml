import QtQuick
import Quickshell
import qs.services

// Vertical edge OSD mirroring notBar/Volume.qml — fill rises from the
// bottom, live % sits in the deck below, tint follows the level.
PanelWindow {
    id: osd

    required property var barWindow

    // warm = dim · yellow = mid · green = bright
    readonly property color accent: BrightnessState.pctDisplay <= 33 ? "#ffb86c"
        : BrightnessState.pctDisplay <= 66 ? "#f1fa8c"
        : "#50fa7b"

    property bool shown: false

    visible: osd.shown && !MiscState.qsOpen
    anchors.right: true
    margins.right: screen.width / 95
    exclusiveZone: 0

    implicitWidth: 38
    implicitHeight: 180
    color: "transparent"
    mask: Region {}

    function bump() {
        osd.shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer

        interval: 1200
        onTriggered: osd.shown = false
    }

    Connections {
        target: BrightnessState

        function onLevelChanged() {
            if (!MiscState.qsOpen)
                osd.bump();
        }
    }

    Item {
        anchors.fill: parent
        opacity: osd.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 5
            color: Qt.rgba(0.04, 0.01, 0.1, 0.75)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1

            Item {
                id: bottomDeck
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 22

                Text {
                    anchors.centerIn: parent
                    text: BrightnessState.pctDisplay
                    color: osd.accent
                    font {
                        pixelSize: 14
                        family: "monofur Nerd Font"
                        bold: true
                        letterSpacing: 1
                    }
                }
            }

            Rectangle {
                id: bar
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: bottomDeck.top
                    leftMargin: 4
                    rightMargin: 4
                    bottomMargin: 0
                }
                height: (parent.height - bottomDeck.height - 4) * Math.max(0, Math.min(BrightnessState.level, 1))
                radius: 3
                color: osd.accent

                Behavior on height {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }
    }
}
