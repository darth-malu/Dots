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

    function fmtTime(secs) {
        if (isNaN(secs) || secs < 0) return "—";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        if (h > 0) return `${h}h ${m}m`;
        return `${m}m`;
    }

    MouseArea {
        id: root

        readonly property bool isCharging: BatteryState.isCharging
        readonly property bool isLow: BatteryState.isLow
        readonly property bool isPluggedIn: BatteryState.isPluggedIn
        readonly property bool isPendingCharge: BatteryState.isPendingCharge
        readonly property bool isPendingDischarge: BatteryState.isPendingDischarge
        readonly property real percentage: BatteryState.batPercentage
        readonly property bool isFull: BatteryState.isFullyCharged

        readonly property color fillColor: isCharging ? "#a6e3a1" : isLow ? "#f38ba8" : Themes.mprisTextColor

        implicitWidth: batteryBody.width
        implicitHeight: batteryBody.height

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button == Qt.MiddleButton)
                batteryBlock.showPopup = !batteryBlock.showPopup;
        }

        Rectangle {
            id: batteryBody
            width: 26
            height: 14
            radius: 3
            color: "#313244"
            border.color: "#585b70"
            border.width: 1
            clip: true

            Item {
                id: shaderSourceItem
                visible: false
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    color: "#313244"
                }

                Rectangle {
                    id: batteryFill
                    anchors {
                        top: parent.top
                        left: parent.left
                        bottom: parent.bottom
                        margins: 1
                    }
                    width: Math.max(0, (parent.width - 2) * root.percentage)
                    radius: 2
                    color: root.fillColor
                }
            }

            Item {
                id: textMaskItem
                visible: false
                anchors.fill: parent

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "⚡"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
                        color: "white"
                        visible: root.isCharging
                    }

                    Text {
                        text: "🔌"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 8 }
                        color: "white"
                        visible: root.isPendingCharge
                    }

                    Text {
                        text: root.isFull ? "⚡" : Math.round(root.percentage * 100)
                        color: "white"
                        font {
                            pixelSize: 11
                            family: "VictorMono Nerd Font"
                            weight: Font.Bold
                        }
                    }
                }
            }

            ShaderEffect {
                anchors.fill: parent

                property var src: ShaderEffectSource {
                    sourceItem: shaderSourceItem
                    hideSource: true
                    live: true
                }

                property var msk: ShaderEffectSource {
                    sourceItem: textMaskItem
                    hideSource: true
                    live: true
                }

                fragmentShader: "varying highp vec2 qt_TexCoord0;
                    uniform sampler2D src;
                    uniform sampler2D msk;
                    uniform highp float qt_Opacity;
                    void main() {
                        highp vec4 s = texture2D(src, qt_TexCoord0);
                        highp vec4 m = texture2D(msk, qt_TexCoord0);
                        gl_FragColor = vec4(s.rgb, s.a * (1.0 - m.a)) * qt_Opacity;
                    }"
            }

            Item {
                anchors.fill: parent

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        Layout.leftMargin: 1
                        Layout.rightMargin: -3
                        text: "⚡"
                        iconSize: 9
                        visible: root.isCharging
                        color: root.fillColor
                    }

                    MaterialSymbol {
                        Layout.leftMargin: 1
                        Layout.rightMargin: -2
                        text: "🔌"
                        iconSize: 8
                        visible: root.isPendingCharge
                        color: root.fillColor
                    }

                    StyledText {
                        font {
                            pixelSize: 11
                            family: "VictorMono Nerd Font"
                            weight: Font.Bold
                        }
                        text: root.isFull ? "⚡" : Math.round(root.percentage * 100)
                        color: root.fillColor
                    }
                }
            }
        }

        Rectangle {
            id: cap
            implicitHeight: 6
            implicitWidth: 2
            color: root.fillColor
            topRightRadius: 999
            bottomRightRadius: 999
            anchors {
                verticalCenter: parent.verticalCenter
                left: batteryBody.right
                leftMargin: 1
            }
        }
    }

    PopupWindow {
        id: batteryPopup
        visible: batteryBlock.showPopup
        grabFocus: true
        color: MiscState.popupSolidBg ? "#1e1e2e" : "transparent"

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
            radius: 10
            layer.enabled: true
            layer.samples: 8
            color: "#1e1e2e"
            border.color: "#45475a"

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
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: `${Math.floor(BatteryState.batPercentage * 100)}%`
                        color: BatteryState.isLow ? "#f38ba8" : BatteryState.isCharging ? "#a6e3a1" : "#cdd6f4"
                        font {
                            pixelSize: 28
                            bold: true
                            family: "ZedMono Nerd Font"
                        }
                    }

                    ColumnLayout {
                        spacing: 2

                        Text {
                            text: BatteryState.isCharging ? "Charging" : BatteryState.isFullyCharged ? "Full" : "Discharging"
                            color: BatteryState.isCharging ? "#a6e3a1" : BatteryState.isFullyCharged ? "#f9e2af" : "#cdd6f4"
                            font { pixelSize: 12; bold: true; family: "Quicksand" }
                        }

                        Text {
                            text: {
                                const chg = batteryBlock.bat.changeRate;
                                return (chg && !isNaN(chg) && chg > 0) ? `${chg.toFixed(1)} W` : "";
                            }
                            color: "#585b70"
                            font { pixelSize: 10; family: "ZedMono Nerd Font" }
                            visible: text !== ""
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: BatteryState.batPercentage < 0.5 ? "" : BatteryState.batPercentage < 0.75 ? "" : BatteryState.batPercentage < 0.95 ? "" : ""
                        color: BatteryState.isLow ? "#f38ba8" : BatteryState.isCharging ? "#a6e3a1" : "#cdd6f4"
                        font { pixelSize: 28; family: "Symbols Nerd Font Mono" }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#313244"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    readonly property var stats: {
                        const b = batteryBlock.bat;
                        const e = b.energy;
                        const ec = b.energyCapacity;
                        const te = b.timeToEmpty;
                        const tf = b.timeToFull;
                        return [
                            { label: "Energy", value: (e && ec && !isNaN(e) && !isNaN(ec)) ? `${e.toFixed(1)} / ${ec.toFixed(1)} Wh` : "—" },
                            { label: "Health", value: (b.healthSupported && b.healthPercentage != null) ? `${Math.round(b.healthPercentage * 100)}%` : "—" },
                            { label: "Time", value: BatteryState.isCharging && tf >= 0 ? `${batteryBlock.fmtTime(tf)} to full` : BatteryState.isDischarging && te >= 0 ? `${batteryBlock.fmtTime(te)} remaining` : "—" },
                            { label: "Model", value: b.model || "—" },
                        ];
                    }

                    Repeater {
                        model: parent.stats.length

                        RowLayout {
                            required property int index
                            spacing: 8
                            Layout.fillWidth: true

                            readonly property var stat: parent.stats[index]

                            Text {
                                text: stat.label
                                color: "#585b70"
                                font { pixelSize: 10; family: "Quicksand" }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: stat.value
                                color: "#a6adc8"
                                font { pixelSize: 10; family: "ZedMono Nerd Font" }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#313244"
                }

                Text {
                    text: "Power Profile"
                    color: "#585b70"
                    font { pixelSize: 10; family: "Quicksand" }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 6
                        color: PowerProfiles.profile === PowerProfile.PowerSaver ? "#313244" : "transparent"
                        border.color: PowerProfiles.profile === PowerProfile.PowerSaver ? "#585b70" : "#313244"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Text { Layout.alignment: Qt.AlignHCenter; text: "🍀"; color: PowerProfiles.profile === PowerProfile.PowerSaver ? "#cdd6f4" : "#585b70"; font { pixelSize: 14; family: "Symbols Nerd Font Mono" } }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Saver"; color: PowerProfiles.profile === PowerProfile.PowerSaver ? "#cdd6f4" : "#585b70"; font { pixelSize: 9; family: "Quicksand"; bold: true } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["sh", "-c", `powerprofilesctl set power-saver && notify-send "Power Profile" "🍀 power-saver" -u low -a Shell`])
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 6
                        color: PowerProfiles.profile === PowerProfile.Balanced ? "#313244" : "transparent"
                        border.color: PowerProfiles.profile === PowerProfile.Balanced ? "#585b70" : "#313244"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Text { Layout.alignment: Qt.AlignHCenter; text: "☯"; color: PowerProfiles.profile === PowerProfile.Balanced ? "#cdd6f4" : "#585b70"; font { pixelSize: 14; family: "Symbols Nerd Font Mono" } }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Balanced"; color: PowerProfiles.profile === PowerProfile.Balanced ? "#cdd6f4" : "#585b70"; font { pixelSize: 9; family: "Quicksand"; bold: true } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["sh", "-c", `powerprofilesctl set balanced && notify-send "Power Profile" "☯ balanced" -u low -a Shell`])
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 6
                        color: PowerProfiles.profile === PowerProfile.Performance ? "#313244" : "transparent"
                        border.color: PowerProfiles.profile === PowerProfile.Performance ? "#585b70" : "#313244"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Text { Layout.alignment: Qt.AlignHCenter; text: "⚡"; color: PowerProfiles.profile === PowerProfile.Performance ? "#cdd6f4" : "#585b70"; font { pixelSize: 14; family: "Symbols Nerd Font Mono" } }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Perf"; color: PowerProfiles.profile === PowerProfile.Performance ? "#cdd6f4" : "#585b70"; font { pixelSize: 9; family: "Quicksand"; bold: true } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["sh", "-c", `powerprofilesctl set performance && notify-send "Power Profile" "⚡ performance" -u low -a Shell`])
                        }
                    }
                }
            }
        }
    }
}
