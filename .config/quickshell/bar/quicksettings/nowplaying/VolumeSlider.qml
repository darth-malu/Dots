import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// ── Volume row: mute button + pill slider + readout ──
RowLayout {
    id: root

    required property PwNode node
    property string glyph
    property string glyphMuted
    property color accent: "#bd93f9"

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
                    return "#6272a4";
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
                color: root.muted ? "#6272a4" : root.accent

                Behavior on width {
                    enabled: !drag.dragging
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
                color: root.muted ? "#6272a4" : root.accent
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.4)
                scale: drag.dragging || drag.containsMouse ? 1.15 : 1.0

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
                    enabled: !drag.dragging
                    NumberAnimation {
                        duration: 60
                    }
                }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                function setFromMouse(mx) {
                    if (!root.ready)
                        return;
                    const r = mapToItem(parent, 0, 0);
                    root.node.audio.volume = Math.max(0, Math.min((mx - r.x) / parent.width, 1));
                    root.adjusted(root.node.audio.volume);
                }
                onPressed: mouse => setFromMouse(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
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
