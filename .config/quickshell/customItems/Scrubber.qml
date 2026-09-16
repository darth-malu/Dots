import QtQuick
import qs.themes

// ── Scrubber — slim seek bar for the now-playing card ──
// Designed to match the card's volume slider language (rounded groove,
// accent fill, floating knob) while staying STATIONARY: the groove keeps a
// fixed height on hover — only the knob and the fill brighten — so the bar
// never bobs when the pointer lands on it. Click/drag anywhere to seek.
Item {
    id: root

    property real ratio: 0
    property color accent: Themes.accent
    signal seeked(real frac)

    implicitWidth: 120
    implicitHeight: 20

    readonly property real clamped: Math.max(0, Math.min(root.ratio, 1))
    // while dragging, follow the pointer exactly (players report position
    // asynchronously, so the fill would lag if we only mirrored that)
    property real dragFrac: -1
    readonly property real shown: drag.pressed ? Math.max(0, Math.min(root.dragFrac, 1)) : root.clamped

    // groove — the only vertical extent; never animates size
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 5
        radius: 2.5
        color: drag.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    // fill
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * root.shown
        height: 5
        radius: 2.5
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)

        Behavior on width {
            enabled: !drag.pressed
            NumberAnimation {
                duration: 200
                easing.type: Easing.Linear
            }
        }

        // bright leading tip — steps aside once it hits the end
        Rectangle {
            visible: root.shown > 0.02 && root.shown < 0.995
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 2.5
            height: parent.height
            radius: 1.25
            color: root.accent
        }
    }

    // knob — fades in on hover; the groove underneath stays put
    Rectangle {
        id: knob
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 12
        radius: 6
        x: Math.max(0, Math.min(parent.width * root.shown - width / 2, parent.width - width))
        color: root.accent
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
        scale: drag.pressed ? 1.2 : drag.containsMouse ? 1.1 : 0.8
        opacity: drag.containsMouse || drag.pressed ? 1 : 0

        Behavior on x {
            enabled: !drag.pressed
            NumberAnimation {
                duration: 200
                easing.type: Easing.Linear
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 90
            }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function apply(mx) {
            root.dragFrac = Math.max(0, Math.min(mx / width, 1));
            root.seeked(root.dragFrac);
        }
        onClicked: mouse => apply(mouse.x)
        onPositionChanged: mouse => {
            if (mouse.buttons & Qt.LeftButton)
                apply(mouse.x);
        }
    }
}