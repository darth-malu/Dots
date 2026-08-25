import QtQuick
import QtQuick.Layouts
import qs.services

// Noctalia-style countdown panel — a thin client of TimerState:
// presets & typed duration arm it, start/pause/reset drive it,
// and the ring mirrors whatever surface changed the shared countdown.
ColumnLayout {
    id: root

    spacing: 10

    // urgency palette — idle/armed lavender, running purple → last 5 min
    // yellow → final minute red; paused orange, finished green
    readonly property color accent: {
        if (TimerState.phase === 3)
            return "#50fa7b";
        if (TimerState.phase === 2)
            return "#ffb86c";
        if (TimerState.active && TimerState.remainingSec <= 60)
            return "#ff5555";
        if (TimerState.active && TimerState.remainingSec <= 300)
            return "#f1fa8c";
        return "#bd93f9";
    }

    // live spinner edits must reach the state even mid-countdown
    function previewSpin() {
        if (!durSpin.dirty || TimerState.phase === 3)
            return;
        TimerState.setDuration(root.spinSecs);
    }

    function pad(n) {
        return String(n).padStart(2, "0");
    }

    function syncSpin() {
        const s = Math.max(0, TimerState.durationSec);
        durSpin.hours = pad(Math.floor(s / 3600));
        durSpin.minutes = pad(Math.floor((s % 3600) / 60));
    }

    // seconds currently shown in the spinners
    readonly property int spinSecs: parseInt(durSpin.hours) * 3600 + parseInt(durSpin.minutes) * 60

    Connections {
        target: TimerState

        // reset lands back at a clean 00:00 — no last-duration memory
        function onPhaseChanged() {
            if (TimerState.phase === 0)
                durSpin.reset();
            ring.requestPaint();
        }

        function onRemainingSecChanged() {
            ring.requestPaint();
        }
    }

    // ── progress ring ──
    Item {
        id: ringWrap

        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 148
        implicitHeight: 148

        Canvas {
            id: ring

            anchors.fill: parent
            contextType: "2d"
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                const cx = width / 2;
                const cy = height / 2;
                const r = width / 2 - 7;
                ctx.reset();
                ctx.lineWidth = 5;
                ctx.lineCap = "round";
                // track
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.07);
                ctx.stroke();
                // progress — sweeps clockwise from 12 o'clock
                const frac = TimerState.durationSec > 0 ? TimerState.remainingSec / TimerState.durationSec : 0;
                if (frac > 0) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac);
                    ctx.strokeStyle = root.accent;
                    ctx.stroke();
                }
            }

            // subtle breathing glow while running
            Rectangle {
                anchors.centerIn: parent
                width: 118
                height: 118
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0.741, 0.576, 0.976, 0.25)
                visible: TimerState.running

                SequentialAnimation on opacity {
                    running: TimerState.running
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { from: 1; to: 0.2; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.2; to: 1; duration: 1600; easing.type: Easing.InOutSine }
                }
            }

            Text {
                anchors.centerIn: parent
                text: TimerState.phase === 0 && TimerState.remainingSec === 0 ? "--:--" : TimerState.formatTime(TimerState.remainingSec)
                color: TimerState.phase === 0 ? "#8b93b8" : root.accent
                font { pixelSize: 26; bold: true; family: "ZedMono Nerd Font" }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: -26
                text: TimerState.running ? "running" : TimerState.phase === 2 ? "paused" : TimerState.phase === 3 ? "time's up" : "ready"
                color: "#8b93b8"
                font { pixelSize: 9; family: "Quicksand"; letterSpacing: 2 }
            }
        }
    }

    // ── duration entry (idle / paused / done — hidden while counting) ──
    RowLayout {
        visible: !TimerState.running
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        TimeSpinner {
            id: durSpin

            // countdown entry — starts and resets at 00:00, never wall-clock.
            // visible while running too: scrolling now RESIZES the countdown
            zeroDefault: true

            // every segment change previews into the shared state — a plain
            // dirty edge-trigger latched after the first scroll and silently
            // swallowed all later ones (the preset-then-spin bug)
            onHoursChanged: root.previewSpin()
            onMinutesChanged: root.previewSpin()
        }
    }

    // ── presets — live-resize a running countdown too ──
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 5

        component PresetChip: Rectangle {
            id: chip

            property int mins

            width: chipTxt.implicitWidth + 16
            height: 22
            radius: 11
            color: chipMa.containsMouse ? Qt.rgba(0.741, 0.576, 0.976, 0.2) : Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: TimerState.durationSec === chip.mins * 60 && TimerState.phase !== 0 ? "#bd93f9" : Qt.rgba(1, 1, 1, 0.07)

            Behavior on color {
                ColorAnimation { duration: 110 }
            }

            scale: chipMa.pressed ? 0.92 : 1

            Behavior on scale {
                NumberAnimation { duration: 80 }
            }

            Text {
                id: chipTxt

                anchors.centerIn: parent
                text: parent.mins >= 60 ? (parent.mins / 60) + "h" : parent.mins + "m"
                color: chipMa.containsMouse ? "#e2d6fb" : "#8b93b8"
                font { pixelSize: 9; bold: true; family: "Quicksand" }
            }

            MouseArea {
                id: chipMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    TimerState.setDuration(chip.mins * 60);
                    root.syncSpin();
                }
            }
        }

        PresetChip { mins: 1 }
        PresetChip { mins: 5 }
        PresetChip { mins: 10 }
        PresetChip { mins: 15 }
        PresetChip { mins: 25 }
        PresetChip { mins: 60 }
    }

    // ── controls ──
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Rectangle {
            id: startBtn

            Layout.preferredWidth: 108
            Layout.preferredHeight: 32
            radius: 10
            color: startMa.containsMouse ? Qt.rgba(0.741, 0.576, 0.976, 0.3) : Qt.rgba(0.741, 0.576, 0.976, 0.18)
            border.width: 1
            border.color: Qt.rgba(0.741, 0.576, 0.976, 0.45)

            scale: startMa.pressed ? 0.94 : 1

            Behavior on scale {
                NumberAnimation { duration: 80 }
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: TimerState.running ? "\uf04c" : "\uf04b"
                    color: "#e2d6fb"
                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: TimerState.running ? "Pause" : TimerState.phase === 2 ? "Resume" : "Start"
                    color: "#e2d6fb"
                    font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 1 }
                }
            }

            MouseArea {
                id: startMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (TimerState.running) {
                        TimerState.pause();
                    } else if (TimerState.phase === 2) {
                        TimerState.resume();
                    } else if (root.spinSecs > 0) {
                        TimerState.start(root.spinSecs);
                    }
                }
            }
        }

        Rectangle {
            id: resetBtn

            Layout.preferredWidth: 72
            Layout.preferredHeight: 32
            radius: 10
            color: resetMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            scale: resetMa.pressed ? 0.94 : 1

            Behavior on scale {
                NumberAnimation { duration: 80 }
            }

            Row {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf0e2"
                    color: "#8b93b8"
                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Reset"
                    color: "#8b93b8"
                    font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 1 }
                }
            }

            MouseArea {
                id: resetMa

                anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                TimerState.reset();
                                durSpin.reset();
                            }
            }
        }
    }
}
