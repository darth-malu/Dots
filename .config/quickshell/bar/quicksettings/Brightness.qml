import QtQuick
import QtQuick.Layouts
import qs.services
import Quickshell

// ── Brightness row: sun icon + pill slider + readout ──
RowLayout {
    id: root

    readonly property color accent: "#f1fa8c"
    readonly property bool ready: BrightnessState.available

    signal adjusted(int percent)

    spacing: 10
    Layout.fillWidth: true
    visible: root.ready

    Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: sunMouse.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.06)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            anchors.centerIn: parent
            text: BrightnessState.pctDisplay <= 15 ? "\uf186" : "\uf185"
            color: sunMouse.containsMouse ? root.accent : Qt.rgba(1, 1, 1, 0.75)
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
            id: sunMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.ready)
                    BrightnessState.setLevel(BrightnessState.pctDisplay > 0 ? 0 : 60);
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
                width: parent.width * Math.min((BrightnessState.level ?? 0), 1)
                height: parent.height
                radius: 3
                color: root.accent

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
                x: Math.max(0, Math.min(parent.width * Math.min((BrightnessState.level ?? 0), 1) - width / 2, parent.width - width))
                color: root.accent
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.4)
                scale: drag.pressed || drag.containsMouse ? 1.15 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutCubic
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
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                function setFromMouse(mx, commit) {
                    if (!root.ready)
                        return false;
                    const r = mapToItem(parent, 0, 0);
                    const pct = Math.max(0, Math.min((mx - r.x) / parent.width, 1));
                    // drags only preview; release/wheel/click commit to hardware
                    BrightnessState.setLevel(pct * 100, commit);
                    root.adjusted(Math.round(pct * 100));
                    return true;
                }

                onPressed: mouse => setFromMouse(mouse.x, true)
                onPositionChanged: mouse => {
                    if (pressed)
                        setFromMouse(mouse.x, false);
                }
                onReleased: mouse => setFromMouse(mouse.x, true)
                onWheel: wheel => {
                    if (!root.ready)
                        return;
                    const cur = BrightnessState.pctDisplay;
                    const next = Math.max(0, Math.min(cur + (wheel.angleDelta.y > 0 ? 5 : -5), 100));
                    BrightnessState.setLevel(next);
                    root.adjusted(next);
                }
            }
        }
    }
}
