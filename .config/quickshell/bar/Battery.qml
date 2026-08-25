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
    visible: BatteryState.available && MiscState.showBattery

    required property var host

    property bool showPopup: false

    // percentage readout is cut into the battery by default; right click toggles it
    property bool showPct: true

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
        onVisibleChanged: if (!visible) showPopup = false

        implicitWidth: batteryBody.width
        implicitHeight: batteryBody.height
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button == Qt.RightButton)
                batteryBlock.showPct = !batteryBlock.showPct;
            else
                batteryBlock.showPopup = !batteryBlock.showPopup;
        }

        // ── Battery glyph — macOS-style: the readout is CUT OUT of the fill,
        // so it stays readable over any charge level, any wallpaper ──
        Item {
            id: batteryBody

            width: 27
            height: 13

            // low/critical: the fill itself blares between a hot base and a bright peak
            readonly property color blareLo: batteryBlock.isCritical ? "#ff5555" : "#ffb86c"
            readonly property color blareHi: batteryBlock.isCritical ? "#ffe2e2" : "#fff3d6"

            // 0..1 blend driving the low-battery pulse (static at 0 otherwise)
            property real blareT: 0

            onBlareTChanged: batCanvas.requestPaint()

            function mix(a, b) {
                return Qt.rgba(a.r + (b.r - a.r) * blareT, a.g + (b.g - a.g) * blareT, a.b + (b.b - a.b) * blareT, 1);
            }

            readonly property color fillColor: batteryBlock.isLow || batteryBlock.isCritical ? mix(blareLo, blareHi) : batteryBlock.accentColor
            readonly property color shellColor: batteryBlock.accentColor

            onFillColorChanged: batCanvas.requestPaint()
            onShellColorChanged: batCanvas.requestPaint()

            SequentialAnimation {
                running: batteryBlock.isLow || batteryBlock.isCritical
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation {
                    target: batteryBody
                    property: "blareT"
                    to: 1
                    duration: 340
                }
                NumberAnimation {
                    target: batteryBody
                    property: "blareT"
                    to: 0
                    duration: 340
                }
            }

            function roundPath(ctx, x, y, w, h, r) {
                ctx.beginPath();
                ctx.moveTo(x + r, y);
                ctx.lineTo(x + w - r, y);
                ctx.arcTo(x + w, y, x + w, y + r, r);
                ctx.lineTo(x + w, y + h - r);
                ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
                ctx.lineTo(x + r, y + h);
                ctx.arcTo(x, y + h, x, y + h - r, r);
                ctx.lineTo(x, y + r);
                ctx.arcTo(x, y, x + r, y, r);
                ctx.closePath();
            }

            Canvas {
                id: batCanvas

                anchors.fill: parent
                antialiasing: true

                Component.onCompleted: requestPaint()
                onVisibleChanged: if (visible)
                    requestPaint()

                // repaint on every state the drawing depends on
                Connections {
                    target: batteryBlock

                    function onPercentageChanged() {
                        batCanvas.requestPaint();
                    }
                    function onPctDisplayChanged() {
                        batCanvas.requestPaint();
                    }
                    function onIsChargingChanged() {
                        batCanvas.requestPaint();
                    }
                    function onIsPendingChargeChanged() {
                        batCanvas.requestPaint();
                    }
                    function onIsFullyChargedChanged() {
                        batCanvas.requestPaint();
                    }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();

                    const w = width;
                    const h = height;
                    const bw = 22; // body outer width; the rest is gap + cap nub

                    // ── shell outline ──
                    ctx.lineWidth = 1.5;
                    ctx.strokeStyle = Qt.rgba(batteryBody.shellColor.r, batteryBody.shellColor.g, batteryBody.shellColor.b, 0.75);
                    batteryBody.roundPath(ctx, 0.75, 0.75, bw - 1.5, h - 1.5, 3);
                    ctx.stroke();

                    // ── charge fill (clipped to the inner well) ──
                    const pct = Math.min(Math.max(batteryBlock.percentage, 0), 1);
                    ctx.save();
                    batteryBody.roundPath(ctx, 2, 2, bw - 4, h - 4, 1.8);
                    ctx.clip();
                    ctx.fillStyle = batteryBody.fillColor;
                    ctx.fillRect(2, 2, Math.max(0, (bw - 4) * pct), h - 4);
                    ctx.restore();

                    // ── cap nub ──
                    ctx.fillStyle = batteryBody.fillColor;
                    batteryBody.roundPath(ctx, bw + 1.25, h * 0.28, 2, h * 0.44, 1);
                    ctx.fill();

                    // ── THE CUTOUT — punch the label through shell+fill so the
                    // bar background shows through; visible at every level ──
                    const label = !batteryBlock.showPct ? ""
                        : (batteryBlock.isCharging || batteryBlock.isPendingCharge || batteryBlock.isFullyCharged) ? "\uf0e7"
                        : String(batteryBlock.pctDisplay);

                    if (label.length > 0) {
                        ctx.globalCompositeOperation = "destination-out";
                        ctx.font = "bold 10px 'ZedMono Nerd Font'";
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        ctx.fillText(label, bw / 2, h / 2 + 0.5);
                        ctx.globalCompositeOperation = "source-over";
                    }
                }
            }
        }
    }

    PopupWindow {
        id: batteryPopup

        visible: batteryBlock.showPopup
        grabFocus: true
        color: "transparent"

        anchor.window: batteryBlock.host
        anchor.rect.x: {
            let g = root.mapToGlobal(0, 0);
            return g.x + (root.width / 2) - (width / 2);
        }
        anchor.rect.y: 33

        implicitWidth: 300
        implicitHeight: popupCol.implicitHeight + 28

        Rectangle {
            anchors.fill: parent
            radius: 12
            layer.enabled: true
            layer.samples: 8
            color: MiscState.popupCardBg
            border.width: 1
            border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

            Shortcut {
                sequence: "Escape"
                onActivated: batteryBlock.showPopup = false
            }

            ColumnLayout {
                id: popupCol

                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 10

                // ── low/critical banner — mirrors the bar pulse with an actionable line ──
                Rectangle {
                    visible: batteryBlock.isLow || batteryBlock.isCritical
                    Layout.fillWidth: true
                    implicitHeight: warnRow.implicitHeight + 12
                    radius: 8
                    color: Qt.rgba(1, 0.33, 0.33, batteryBlock.isCritical ? 0.14 : 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 0.33, 0.33, batteryBlock.isCritical ? 0.5 : 0.3)

                    RowLayout {
                        id: warnRow
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: batteryBlock.isCritical ? "" : ""
                            color: "#ff5555"
                            font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (batteryBlock.isCritical) {
                                    const t = BatteryState.fmtTime(batteryBlock.bat.timeToEmpty);
                                    return `Battery critical — ${batteryBlock.pctDisplay}%${t ? ` (~${t} left)` : ""}`;
                                }
                                const t = BatteryState.fmtTime(batteryBlock.bat.timeToEmpty);
                                return `Battery low — ${batteryBlock.pctDisplay}%${t ? ` (~${t} remaining)` : ""}`;
                            }
                            color: batteryBlock.isCritical ? "#ff5555" : "#ffb86c"
                            wrapMode: Text.WordWrap
                            font { pixelSize: 11; bold: true; family: "Quicksand" }
                        }
                    }

                    SequentialAnimation on opacity {
                        running: batteryBlock.isCritical && visible
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.55; duration: 800 }
                        NumberAnimation { to: 1; duration: 800 }
                    }
                }

                // ── Header ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        spacing: 4

                        Text {
                            // purely temporal readout — the icon already carries the state
                            text: {
                                const b = batteryBlock.bat;
                                if (batteryBlock.isCharging) {
                                    const t = BatteryState.fmtTime(b.timeToFull);
                                    return t ? `${t} to full` : "";
                                }
                                if (batteryBlock.isPendingCharge)
                                    return "";
                                if (batteryBlock.isFullyCharged)
                                    return "";
                                if (BatteryState.isDischarging) {
                                    const t = BatteryState.fmtTime(b.timeToEmpty);
                                    return t ? `${t} remaining` : "";
                                }
                                return "";
                            }
                            color: "#f8f8f2"
                            font { pixelSize: 13; bold: true; family: "Quicksand" }
                            visible: text !== ""
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // single percentage readout for the whole popup
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: batteryBlock.pctDisplay + "%"
                        color: batteryBlock.accentColor
                        font { pixelSize: 14; bold: true; family: "ZedMono Nerd Font" }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }

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

                    // compact status glyph — matches the header text scale
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: batteryBlock.batteryGlyph
                        color: batteryBlock.accentColor
                        font { pixelSize: 15; family: "Symbols Nerd Font Mono" }

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

                // ── Profile list — one sleek row per profile ──
                Repeater {
                    model: [
                        { glyph: "\uf06c", name: "Power Saver", profile: PowerProfile.PowerSaver, tint: "#50fa7b" },
                        { glyph: "\uf24e", name: "Balanced", profile: PowerProfile.Balanced, tint: "#bd93f9" },
                        { glyph: "\uf0e7", name: "Performance", profile: PowerProfile.Performance, tint: "#ff5555" }
                    ]

                    delegate: Rectangle {
                        id: seg

                        required property var modelData

                        readonly property bool active: PowerProfiles.profile === seg.modelData.profile
                        readonly property color tint: seg.modelData.tint

                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 8
                        color: seg.active ? Qt.rgba(seg.tint.r, seg.tint.g, seg.tint.b, 0.13)
                            : segHover.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                        border.width: seg.active ? 1 : 0
                        border.color: Qt.rgba(seg.tint.r, seg.tint.g, seg.tint.b, 0.45)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            spacing: 8

                            Text {
                                text: seg.modelData.glyph
                                color: seg.active ? seg.tint : segHover.hovered ? "#b8bfcb" : "#6272a4"
                                font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
                            }

                            Text {
                                text: seg.modelData.name
                                color: seg.active ? "#f8f8f2" : "#b8bfcb"
                                font { pixelSize: 10; bold: true; family: "Quicksand" }
                                Layout.fillWidth: true
                            }

                            // radio indicator
                            Rectangle {
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 7
                                color: "transparent"
                                border.width: 1.5
                                border.color: seg.active ? seg.tint : "#44475a"

                                Rectangle {
                                    anchors.centerIn: parent
                                    implicitWidth: 6
                                    implicitHeight: 6
                                    radius: 3
                                    color: seg.tint
                                    visible: seg.active
                                }
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
