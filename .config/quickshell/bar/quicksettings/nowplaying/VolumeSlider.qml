import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.themes

// ── Volume row: mute button + pill slider + readout ──
RowLayout {
    id: root

    required property PwNode node
    property string glyph
    property string glyphMuted
    property color accent: Themes.accent

    readonly property bool ready: node !== null && node.audio !== null
    readonly property bool muted: root.node?.audio?.muted ?? false
    readonly property real level: root.node?.audio?.volume ?? 0

    signal adjusted(real level)

    spacing: 10
    Layout.fillWidth: true
    visible: ready

    Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: muteMouse.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : root.muted ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.06)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        border.width: root.muted || muteMouse.containsMouse ? 1 : 0
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3)

        Behavior on border.width {
            NumberAnimation {
                duration: 80
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.muted ? root.glyphMuted : root.glyph
            color: {
                if (root.muted)
                    return Themes.muted;
                return muteMouse.containsMouse ? root.accent : Qt.rgba(1, 1, 1, 0.75);
            }

            font {
                pixelSize: 12
                family: "Symbols Nerd Font Mono"
            }

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        MouseArea {
            id: muteMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.ready)
                    root.node.audio.muted = !root.node.audio.muted;
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 14
        visible: root.ready

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.07)

            Rectangle {
                width: parent.width * Math.min(root.level, 1)
                height: parent.height
                radius: 3
                // pastel wash + bright leading edge; grey when muted
                color: root.muted ? Qt.rgba(0.38, 0.45, 0.64, 0.35) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4)

                Rectangle {
                    // leading tip — tucks inside the groove and steps aside
                    // once the knob reaches the end (no blob at 100%)
                    visible: !root.muted && root.level < 0.995
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2.5
                    radius: 1.25
                    height: parent.height
                    color: root.accent
                }

                Behavior on width {
                    enabled: !drag.pressed
                    NumberAnimation {
                        duration: 60
                    }
                }
            }

            Rectangle {
                id: knob
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 6
                x: Math.max(0, Math.min(parent.width * Math.min(root.level, 1) - width / 2, parent.width - width))
                color: root.muted ? Themes.muted : root.accent
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
                scale: drag.pressed || drag.containsMouse ? 1.15 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Behavior on x {
                    enabled: !drag.pressed
                    NumberAnimation {
                        duration: 60
                    }
                }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                anchors.margins: -4
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                function setFromMouse(mx) {
                    if (!root.ready)
                        return;
                    const r = mapToItem(parent, 0, 0);
                    root.node.audio.volume = Math.max(0, Math.min((mx - r.x) / parent.width, 1));
                    root.adjusted(root.node.audio.volume);
                }
                onPressed: mouse => {
                    // right-click anywhere on the track mutes the sink
                    if (mouse.button === Qt.RightButton) {
                        if (root.ready)
                            root.node.audio.muted = !root.node.audio.muted;
                        return;
                    }
                    setFromMouse(mouse.x);
                }
                onPositionChanged: mouse => {
                    if (mouse.buttons & Qt.LeftButton)
                        setFromMouse(mouse.x);
                }
                onWheel: wheel => {
                    if (!root.ready)
                        return;
                    const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    root.node.audio.volume = Math.max(0, Math.min(root.node.audio.volume + step, 1));
                    root.adjusted(root.node.audio.volume);
                }
            }
        }
    }
}
