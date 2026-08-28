pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.themes

// Speaker + mic glyphs for the bar — bare icons, no pill background,
// sized like the other tray icons.
//   · scroll adjusts volume; a % label flashes inline beside the icon
//     being scrolled and fades away
//   · right-click toggles mute (label flips red)
RowLayout {
    id: root

    required property var host

    Layout.alignment: Qt.AlignVCenter
    spacing: 8

    readonly property bool pipewireReady: PipewireState.pipewireReady

    component VolIcon: Item {
        id: vi

        required property int chan // 0 output · 1 mic
        readonly property bool isOut: chan === 0
        readonly property var node: isOut ? PipewireState.outputSink : PipewireState.inputSink
        // pastel, low-key accents — the icons should whisper
        readonly property color accent: isOut ? (MiscState.barSolid ? Themes.accentSoft : Qt.rgba(0.7, 0.62, 0.85, 0.6)) : (MiscState.barSolid ? Themes.accent2 : Qt.rgba(0.55, 0.78, 0.85, 0.6))
        readonly property color mutedColor: "#ff5555"

        // true while the wheel is active — drives the inline readout
        property bool flashing: false

        implicitHeight: 18
        implicitWidth: row.implicitWidth

        RowLayout {
            id: row

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: {
                    const a = vi.node?.audio;
                    const muted = (a?.muted) ?? true;
                    const v = a?.volume ?? 0;
                    if (vi.isOut) {
                        if (muted || v === 0) return "\uf026";
                        if (v <= 0.33) return "\uf027";
                        if (v <= 0.66) return "\uf027";
                        return "\uf028";
                    }
                    return muted ? "\uf131" : "\uf130";
                }
                opacity: {
                    if (vi.isOut) {
                        const a = vi.node?.audio;
                        const muted = (a?.muted) ?? true;
                        const v = a?.volume ?? 0;
                        if (muted || v === 0) return 1;
                        if (v <= 0.33) return 0.55;
                        if (v <= 0.66) return 0.75;
                        return 1;
                    }
                    return viMa.containsMouse ? 1 : 0.8;
                }
                color: ((vi.node?.audio?.muted) ?? true) ? vi.mutedColor : Qt.rgba(0.91, 0.91, 0.96, 0.62)
                font {
                    pixelSize: 15
                    family: "Symbols Nerd Font Mono"
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            // event-only readout — appears while scrolling, then fades
            Text {
                Layout.leftMargin: 4
                Layout.maximumWidth: 42
                visible: false
                opacity: vi.flashing ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: vi.flashing ? 60 : 260
                        easing.type: Easing.OutQuad
                    }
                }
                text: ((vi.node?.audio?.muted) ?? false) ? "muted" : Math.round(((vi.node?.audio?.volume) ?? 0) * 100) + "%"
                color: ((vi.node?.audio?.muted) ?? false) ? vi.mutedColor : vi.accent
                font {
                    pixelSize: 10
                    bold: true
                    family: "ZedMono Nerd Font"
                }
            }
        }

        Timer {
            id: flashTimer

            interval: 850
            onTriggered: vi.flashing = false
        }

        MouseArea {
            id: viMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.RightButton

            onClicked: mouse => {
                const a = vi.node?.audio;
                if (!a)
                    return;
                a.muted = !a.muted;
                vi.flashing = true;
                flashTimer.restart();
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => {
                const a = vi.node?.audio;
                if (!a)
                    return;
                const step = ev.angleDelta.y > 0 ? 0.05 : -0.05;
                a.volume = Math.max(0, Math.min(a.volume + step, 1));
                vi.flashing = true;
                flashTimer.restart();
                ev.accepted = true;
            }
        }
    }

    VolIcon {
        chan: 0
        visible: root.pipewireReady && MiscState.showVolumeOut
    }

    VolIcon {
        chan: 1
        visible: root.pipewireReady && MiscState.showVolumeIn
    }
}
