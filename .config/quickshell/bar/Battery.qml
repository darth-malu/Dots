import QtQuick
import QtQuick.Layouts
import qs.services
import qs.customItems
import Quickshell
import Quickshell.Services.UPower
import qs.themes

RowLayout {
    id: batteryBlock

    Layout.alignment: Qt.AlignVCenter
    spacing: 6
    visible: BatteryState.available

    required property var host

    property bool showPopup: false

    // percentage readout inside the battery — off by default, left click toggles
    property bool showPct: false

    readonly property UPowerDevice bat: UPower.displayDevice

    readonly property bool isCharging: BatteryState.isCharging
    readonly property bool isPendingCharge: BatteryState.isPendingCharge
    readonly property bool isLow: BatteryState.isLow
    readonly property bool isCritical: BatteryState.isCritical
    readonly property bool isFullyCharged: BatteryState.isFullyCharged
    readonly property real percentage: BatteryState.batPercentage
    readonly property int pctDisplay: BatteryState.pctDisplay

    // green = charging · yellow = pending · red = critical · orange = low · purple = normal
    readonly property color accentColor: isCharging ? "#50fa7b"
        : isPendingCharge ? "#f1fa8c"
        : isCritical ? "#ff5555"
        : isLow ? "#ffb86c"
        : "#bd93f9"


    readonly property string batteryGlyph:
        isCharging ? "\uf0e7"
        : isPendingCharge ? "\uf1e6"
        : percentage < 0.10 ? "\uf244"
        : percentage < 0.35 ? "\uf243"
        : percentage < 0.60 ? "\uf242"
        : percentage < 0.90 ? "\uf241"
        : "\uf240"

    MouseArea {
        id: root

        implicitWidth: batteryBody.width + 4 + cap.width
        implicitHeight: batteryBody.height
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button == Qt.RightButton)
                batteryBlock.showPct = !batteryBlock.showPct;
            else
                batteryBlock.showPopup = !batteryBlock.showPopup;
        }

        // ── Battery body (fixed width — never resizes with the value) ──
        Rectangle {
            id: batteryBody

            width: 27
            height: 15
            radius: 3
            color: "#343746"
            border.width: 1
            border.color: Qt.rgba(batteryBlock.accentColor.r, batteryBlock.accentColor.g, batteryBlock.accentColor.b, 0.55)

            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                }
            }

            clip: true

            // ── Fill level ──
            Rectangle {
                id: batteryFill

                anchors {
                    top: parent.top
                    left: parent.left
                    bottom: parent.bottom
                    margins: 2
                }

                width: Math.max(0, (parent.width - 4) * Math.min(Math.max(batteryBlock.percentage, 0), 1))
                radius: 2.5
                color: batteryBlock.accentColor

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }

                // full-charge bolt badge — centered over the body, overlapping its border
                Text {
                    visible: batteryBlock.isFullyCharged
                    anchors.centerIn: parent
                    text: "\uf0e7"
                    font { pixelSize: 12; family: "Symbols Nerd Font Mono"; weight: Font.Bold }
                    color: "#f8f8f2"
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                }
            }

            // ── Charge status icon — centered in the body while plugged in ──
            Text {
                anchors.centerIn: parent
                visible: batteryBlock.isCharging || batteryBlock.isPendingCharge
                text: batteryBlock.isPendingCharge ? "\uf1e6" : "\uf0e7"
                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                color: "#f8f8f2"
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.65)
            }

            // ── Percentage — inside the body, outlined for legibility over the fill ──
            Text {
                anchors.centerIn: parent
                visible: batteryBlock.showPct && !batteryBlock.isCharging && !batteryBlock.isPendingCharge && !batteryBlock.isFullyCharged
                text: `${batteryBlock.pctDisplay}`
                color: "#f8f8f2"
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.75)
                font { pixelSize: 9; bold: true; family: "ZedMono Nerd Font" }
            }
        }

        // ── Cap nub — separated from the body by a small gap (macOS style) ──
        Rectangle {
            id: cap

            anchors {
                verticalCenter: parent.verticalCenter
                left: batteryBody.right
                leftMargin: 1.5
            }

            implicitWidth: 2.5
            implicitHeight: 8
            radius: 1
            color: batteryBlock.accentColor

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }
    }

    PopupWindow {
        id: batteryPopup

        visible: batteryBlock.showPopup
        grabFocus: true
        color: MiscState.popupSolidBg ? "#282a36" : "transparent"

        anchor.window: batteryBlock.host
        anchor.rect.x: {
            let g = root.mapToGlobal(0, 0);
            return g.x + (root.width / 2) - (width / 2);
        }
        anchor.rect.y: 33

        implicitWidth: 260
        implicitHeight: popupCol.implicitHeight + 28

        Rectangle {
            anchors.fill: parent
            radius: 12
            layer.enabled: true
            layer.samples: 8
            color: "#282a36"
            border.width: 1
            border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

            Shortcut {
                sequence: "Escape"
                onActivated: batteryBlock.showPopup = false
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: batteryBlock.showPopup = false
            }

            ColumnLayout {
                id: popupCol

                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 10

                // ── Header ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        spacing: 4

                        Text {
                            text: {
                                const b = batteryBlock.bat;
                                const p = ` · ${batteryBlock.pctDisplay}%`;
                                if (batteryBlock.isCharging) {
                                    const t = BatteryState.fmtTime(b.timeToFull);
                                    return t ? `Charging · ${t} to full${p}` : `Charging${p}`;
                                }
                                if (batteryBlock.isPendingCharge)
                                    return `Plugged in${p}`;
                                if (batteryBlock.isFullyCharged)
                                    return `Fully charged${p}`;
                                if (BatteryState.isDischarging) {
                                    const t = BatteryState.fmtTime(b.timeToEmpty);
                                    return t ? `${t} remaining${p}` : `Discharging${p}`;
                                }
                                return "";
                            }
                            color: "#f8f8f2"
                            font { pixelSize: 13; bold: true; family: "Quicksand" }
                            visible: text !== ""
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // graph toggle (same style as the network popups)
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 22
                        implicitHeight: 18
                        radius: 6
                        color: batGraphMa.containsMouse || BatteryState.graphEnabled ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.16) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\uf1fe"
                            color: BatteryState.graphEnabled ? "#bd93f9" : "#6272a4"
                            font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                        }

                        MouseArea {
                            id: batGraphMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BatteryState.graphEnabled = !BatteryState.graphEnabled
                        }
                    }

                    Text {
                        text: batteryBlock.batteryGlyph
                        color: batteryBlock.accentColor
                        font { pixelSize: 34; family: "Symbols Nerd Font Mono" }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }
                }

                // ── Charge history graph ──
                ColumnLayout {
                    visible: BatteryState.graphEnabled
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "history · last hour"
                            color: "#6272a4"
                            font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: `${batteryBlock.pctDisplay}%`
                            color: batteryBlock.accentColor
                            font { pixelSize: 9; family: "ZedMono Nerd Font" }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.03)
                        clip: true

                        Canvas {
                            id: graphCanvas

                            anchors.fill: parent
                            anchors.margins: 6

                            property var samples: BatteryState.levelHistory

                            onSamplesChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                const ac = batteryBlock.accentColor;
                                const r = Math.round(ac.r * 255);
                                const g = Math.round(ac.g * 255);
                                const b = Math.round(ac.b * 255);

                                // reference gridlines at ~100/50/0%
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.07)";
                                ctx.lineWidth = 1;
                                for (const fy of [0.05, 0.5, 0.95]) {
                                    ctx.beginPath();
                                    ctx.moveTo(0, height * fy);
                                    ctx.lineTo(width, height * fy);
                                    ctx.stroke();
                                }

                                const vals = graphCanvas.samples;
                                if (!vals || vals.length < 2)
                                    return;

                                const stepX = width / (vals.length - 1);
                                const yFor = v => height - (Math.min(Math.max(v, 0), 1) * (height - 6) + 3);

                                // area fill under the curve
                                const grad = ctx.createLinearGradient(0, 0, 0, height);
                                grad.addColorStop(0, `rgba(${r}, ${g}, ${b}, 0.32)`);
                                grad.addColorStop(1, `rgba(${r}, ${g}, ${b}, 0.02)`);

                                ctx.beginPath();
                                ctx.moveTo(0, yFor(vals[0]));
                                for (let i = 1; i < vals.length; i++)
                                    ctx.lineTo(i * stepX, yFor(vals[i]));
                                ctx.lineTo(width, height);
                                ctx.lineTo(0, height);
                                ctx.closePath();
                                ctx.fillStyle = grad;
                                ctx.fill();

                                // line on top
                                ctx.beginPath();
                                ctx.moveTo(0, yFor(vals[0]));
                                for (let i = 1; i < vals.length; i++)
                                    ctx.lineTo(i * stepX, yFor(vals[i]));
                                ctx.strokeStyle = `rgb(${r}, ${g}, ${b})`;
                                ctx.lineWidth = 2;
                                ctx.lineJoin = "round";
                                ctx.lineCap = "round";
                                ctx.stroke();

                                // endpoint dot
                                ctx.beginPath();
                                ctx.arc(width - 2, yFor(vals[vals.length - 1]), 2.5, 0, Math.PI * 2);
                                ctx.fillStyle = `rgb(${r}, ${g}, ${b})`;
                                ctx.fill();
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#343746"
                }

                Text {
                    text: "Power Profile"
                    color: "#6272a4"
                    font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 1 }
                }

                // ── Segmented profile control ──
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 9
                    color: "#343746"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 3

                        Repeater {
                            model: [
                                { glyph: "\uf06c", name: "Saver", profile: PowerProfile.PowerSaver, tint: "#96e6a1" },
                                { glyph: "\uf24e", name: "Balanced", profile: PowerProfile.Balanced, tint: "#c3b8f5" },
                                { glyph: "\uf0e7", name: "Perf", profile: PowerProfile.Performance, tint: "#8fd8e8" }
                            ]

                            delegate: Rectangle {
                                id: seg

                                required property var modelData

                                readonly property bool active: PowerProfiles.profile === seg.modelData.profile

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 7
                                color: seg.active ? seg.modelData.tint : segHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: seg.modelData.glyph
                                        color: seg.active ? "#282a36" : seg.modelData.tint
                                        font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
                                    }

                                    Text {
                                        text: seg.modelData.name
                                        color: seg.active ? "#282a36" : "#b8bfcb"
                                        font { pixelSize: 9; bold: true; family: "Quicksand" }
                                    }
                                }

                                HoverHandler {
                                    id: segHover
                                }

                                TapHandler {
                                    onTapped: PowerProfiles.profile = seg.modelData.profile
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
