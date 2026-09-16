import QtQuick
import qs.themes

// ── SeekStrip — bottom-embedded progress/seek bar for the now-playing card ──
// The groove is pinned to the BOTTOM edge so the strip reads as a floor line
// that adheres to the card's bottom border. A permanent glowing head dot marks
// the playhead; hovering/grabbing grows it into a real knob and floats a
// cur/total time pill above it. Pass `length` (seconds) to enable the time
// readout — without it the pill stays hidden and the strip degrades to a
// plain progress/seek line.
Item {
    id: root

    property real ratio: 0
    property real length: 0
    property color accent: Themes.accent
    signal seeked(real frac)

    implicitHeight: 16

    readonly property real clamped: Math.max(0, Math.min(root.ratio, 1))
    // while dragging, follow the pointer exactly (players report position
    // asynchronously, so the fill would lag if we only mirrored that)
    property real dragFrac: -1
    readonly property real shown: drag.pressed ? Math.max(0, Math.min(root.dragFrac, 1)) : root.clamped

    // mm:ss helpers for the pill — position/length arrive in seconds
    function fmt(s) {
        s = Math.max(0, Math.floor(s));
        const m = Math.floor(s / 60);
        const sec = s % 60;
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }
    readonly property string curTime: fmt(root.length * root.shown)
    readonly property string totalTime: fmt(root.length)
    // the head dot must tuck away at the extremes (no blob when empty/finished)
    readonly property bool headVisible: root.shown > 0.02 && root.shown < 0.995
    readonly property real headX: Math.max(0, Math.min(root.width * root.shown - head.width / 2, root.width - head.width))

    // groove — the only vertical extent; never grows (stationary floor line)
    Rectangle {
        id: groove
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 6
        radius: 3
        color: drag.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        // inset top highlight — turns the flat groove into a machined track
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            radius: 0.5
            color: Qt.rgba(1, 1, 1, 0.18)
        }
    }

    // fill — bright accent wash leading from the left edge
    Rectangle {
        id: fill
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: parent.width * root.shown
        height: 6
        radius: 3
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8)

        Behavior on width {
            enabled: !drag.pressed
            NumberAnimation {
                duration: 120
            }
        }
    }

    // head dot — the playhead; a soft glowing orb at rest that grows into a
    // grip-able knob on hover/drag so seeking is always signposted
    Rectangle {
        id: head
        x: root.headX
        anchors.verticalCenter: groove.verticalCenter
        width: drag.containsMouse ? 13 : 7
        height: width
        radius: width / 2
        color: root.accent
        border.width: drag.containsMouse ? 1 : 0
        border.color: Qt.rgba(0, 0, 0, 0.4)
        visible: root.headVisible || drag.pressed

        Behavior on width {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutCubic
            }
        }

        // halo — the always-present glow; keeps the head readable over art
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 2.2
            height: width
            radius: width / 2
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, drag.containsMouse ? 0.3 : 0.22)
            z: -1
        }
    }

    // time pill — floats over the strip on hover/drag once a track length is
    // known; "grip, don't guess" feedback while seeking
    Rectangle {
        id: pill
        anchors.bottom: groove.top
        anchors.bottomMargin: 6
        x: Math.max(3, Math.min(head.x + head.width / 2 - width / 2, root.width - width - 3))
        visible: root.length > 0 && (drag.containsMouse || drag.pressed)
        opacity: visible ? 1 : 0
        color: Qt.rgba(0, 0, 0, 0.6)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        radius: 4
        implicitWidth: timeRow.implicitWidth + 10
        implicitHeight: timeRow.implicitHeight + 4

        Behavior on opacity {
            NumberAnimation {
                duration: 90
            }
        }

        Row {
            id: timeRow

            anchors.centerIn: parent
            spacing: 4

            Text {
                text: root.curTime
                color: Themes.fg
                font {
                    pixelSize: 9
                    bold: true
                    family: "ZedMono Nerd Font"
                }
            }

            Text {
                text: "/"
                color: Themes.dim
                font {
                    pixelSize: 9
                    family: "ZedMono Nerd Font"
                }
            }

            Text {
                text: root.totalTime
                color: Themes.dim
                font {
                    pixelSize: 9
                    family: "ZedMono Nerd Font"
                }
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