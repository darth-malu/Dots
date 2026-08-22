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

        readonly property bool chargingVisible: batteryBlock.isCharging || batteryBlock.isPendingCharge

        implicitWidth: batteryBody.width + cap.width + 1
        implicitHeight: batteryBody.height
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button == Qt.MiddleButton || mouse.button == Qt.LeftButton)
                batteryBlock.showPopup = !batteryBlock.showPopup;
        }

        // ── Battery body ──
        Rectangle {
            id: batteryBody

            // dynamic width so "100%" never clips (old design clipped at a fixed 26px)
            width: Math.max(34, innerRow.implicitWidth + 16)
            height: 17
            radius: 4
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
                radius: 2
                color: batteryBlock.accentColor

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }

            // ── Overlay: bolt/plug + percentage ──
            RowLayout {
                id: innerRow

                anchors.centerIn: parent
                spacing: 3

                MaterialSymbol {
                    visible: root.chargingVisible
                    text: batteryBlock.isCharging ? "\uf0e7" : "\uf1e6"
                    iconSize: 10
                    color: "#f8f8f2"
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                }

                Text {
                    id: pctText

                    text: batteryBlock.isFullyCharged && !batteryBlock.isCharging ? "" : batteryBlock.pctDisplay + "%"
                    visible: text !== ""
                    font {
                        pixelSize: 12
                        family: "ZedMono Nerd Font"
                        weight: Font.Bold
                    }
                    // white text + dark outline stays readable over any fill/state color
                    color: "#f8f8f2"
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.7)
                }
            }
        }

        // ── Cap nub ──
        Rectangle {
            id: cap

            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: -1

            implicitWidth: 2.5
            implicitHeight: 7
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
                        spacing: 2

                        Text {
                            text: `${batteryBlock.pctDisplay}%`
                            color: batteryBlock.accentColor
                            font {
                                pixelSize: 28
                                bold: true
                                family: "ZedMono Nerd Font"
                            }
                        }

                        Text {
                            text: {
                                const b = batteryBlock.bat;
                                if (batteryBlock.isCharging) {
                                    const t = BatteryState.fmtTime(b.timeToFull);
                                    return t ? `Charging · ${t} to full` : "Charging";
                                }
                                if (batteryBlock.isPendingCharge)
                                    return "Plugged in";
                                if (batteryBlock.isFullyCharged)
                                    return "Fully charged";
                                if (BatteryState.isDischarging) {
                                    const t = BatteryState.fmtTime(b.timeToEmpty);
                                    return t ? `${t} remaining` : "Discharging";
                                }
                                return "";
                            }
                            color: "#b8bfcb"
                            font { pixelSize: 10; family: "Quicksand" }
                            visible: text !== ""
                        }

                        Text {
                            text: {
                                const chg = batteryBlock.bat.changeRate;
                                return (chg && !isNaN(chg) && chg > 0.1) ? `${chg.toFixed(1)} W` : "";
                            }
                            color: "#6272a4"
                            font { pixelSize: 9; family: "ZedMono Nerd Font" }
                            visible: text !== ""
                        }
                    }

                    Item { Layout.fillWidth: true }

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

                // ── Level bar ──
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: "#343746"

                    Rectangle {
                        anchors.fill: parent
                        anchors.rightMargin: parent.width * (1 - Math.min(Math.max(batteryBlock.percentage, 0), 1))
                        radius: 3
                        color: batteryBlock.accentColor

                        Behavior on anchors.rightMargin {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#343746"
                }

                // ── Stats (energy + time) ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    component StatRow: RowLayout {
                        id: srow

                        required property string label
                        required property string value
                        spacing: 8
                        Layout.fillWidth: true

                        Text {
                            text: srow.label
                            color: "#6272a4"
                            font { pixelSize: 10; family: "Quicksand" }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: srow.value
                            color: "#f8f8f2"
                            font { pixelSize: 10; family: "ZedMono Nerd Font" }
                        }
                    }

                    StatRow {
                        label: "Energy"
                        value: {
                            const b = batteryBlock.bat;
                            const e = b.energy;
                            const ec = b.energyCapacity;
                            return (e && ec && !isNaN(e) && !isNaN(ec)) ? `${e.toFixed(1)} / ${ec.toFixed(1)} Wh` : "—";
                        }
                    }

                    StatRow {
                        label: "Time"
                        value: {
                            const b = batteryBlock.bat;
                            if (batteryBlock.isCharging)
                                return BatteryState.fmtTime(b.timeToFull) ?? "—";
                            if (BatteryState.isDischarging)
                                return BatteryState.fmtTime(b.timeToEmpty) ?? "—";
                            return "—";
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    component ProfileButton: Rectangle {
                        id: pbtn

                        required property string glyph
                        required property string name
                        required property int profile
                        property bool active: PowerProfiles.profile === pbtn.profile

                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 8
                        color: active ? Qt.rgba(0.74, 0.58, 0.98, 0.18) : hover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        border.color: active ? "#bd93f9" : "#343746"
                        border.width: 1

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: pbtn.glyph
                                color: pbtn.active ? "#bd93f9" : "#6272a4"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: pbtn.name
                                color: pbtn.active ? "#f8f8f2" : "#6272a4"
                                font { pixelSize: 9; family: "Quicksand"; bold: true }
                            }
                        }

                        HoverHandler {
                            id: hover
                        }

                        TapHandler {
                            onTapped: PowerProfiles.profile = pbtn.profile
                        }
                    }

                    ProfileButton {
                        glyph: "\uf06c"
                        name: "Saver"
                        profile: PowerProfile.PowerSaver
                    }

                    ProfileButton {
                        glyph: "\uf24e"
                        name: "Balanced"
                        profile: PowerProfile.Balanced
                    }

                    ProfileButton {
                        glyph: "\uf0e7"
                        name: "Performance"
                        profile: PowerProfile.Performance
                    }
                }
            }
        }
    }
}
