import QtQuick
import QtQuick.Layouts
import qs.services

// Reusable speed-test card — used in the Wi-Fi popup and the settings
// network page. Idle → big run pill · running → live phase readout with
// cancel · done → three-column results with rerun.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: contentCol.implicitHeight + 20
    radius: 10
    color: Qt.rgba(1, 1, 1, 0.03)
    border.width: 1
    border.color: "#343746"

    ColumnLayout {
        id: contentCol

        anchors {
            fill: parent
            margins: 10
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "\uf0e4"
                color: "#bd93f9"
                font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
            }

            Text {
                Layout.fillWidth: true
                text: "Speed test"
                color: "#b8bfcb"
                font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 1 }
            }

            // cancel / rerun corner button while active or finished
            Rectangle {
                visible: SpeedtestState.running || SpeedtestState.finished
                implicitWidth: 22
                implicitHeight: 18
                radius: 6
                color: stCorner.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.14) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: SpeedtestState.running ? "\uf04d" : "\uf021"
                    color: stCorner.containsMouse ? "#ff5555" : "#6272a4"
                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                }

                MouseArea {
                    id: stCorner

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SpeedtestState.running ? SpeedtestState.cancel() : SpeedtestState.start()
                }
            }
        }

        // ── idle prompt ──
        Rectangle {
            visible: !SpeedtestState.running && !SpeedtestState.finished
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: runRow.implicitWidth + 28
            implicitHeight: runRow.implicitHeight + 14
            radius: 14
            color: runMa.containsMouse ? Qt.rgba(0.741, 0.576, 0.976, 0.2) : Qt.rgba(0.741, 0.576, 0.976, 0.1)
            border.width: 1
            border.color: Qt.rgba(0.741, 0.576, 0.976, 0.35)

            RowLayout {
                id: runRow

                anchors.centerIn: parent
                spacing: 7

                Text {
                    text: "\uf052"
                    color: "#bd93f9"
                    font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                }

                Text {
                    text: "Run test"
                    color: "#f8f8f2"
                    font { pixelSize: 11; bold: true; family: "Quicksand" }
                }
            }

            MouseArea {
                id: runMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SpeedtestState.start()
            }
        }

        // ── running phase readout ──
        ColumnLayout {
            visible: SpeedtestState.running
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (SpeedtestState.phase === "ping")
                        return "measuring latency…";
                    if (SpeedtestState.phase === "down")
                        return "testing download…";
                    if (SpeedtestState.phase === "up")
                        return "testing upload…";
                    return "starting…";
                }
                color: "#b8bfcb"
                font { pixelSize: 11; bold: true; family: "Quicksand" }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 5
                radius: 2.5
                color: Qt.rgba(1, 1, 1, 0.06)

                Rectangle {
                    readonly property real frac: {
                        const p = SpeedtestState.phase;
                        if (p === "down" && SpeedtestState.pingMs >= 0)
                            return 0.45;
                        if (p === "up" && SpeedtestState.downMbps >= 0)
                            return 0.78;
                        if (!SpeedtestState.running)
                            return 1;
                        return p === "ping" ? 0.15 : p === "down" ? 0.45 : 0.78;
                    }

                    width: parent.width * frac + (parent.width * 0.07 * Math.sin(root.wobble))
                    height: parent.height
                    radius: 2.5
                    color: "#bd93f9"

                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }

            Timer {
                interval: 90
                repeat: true
                running: true
                onTriggered: root.wobble += 0.35
            }
        }

        // ── results ──
        RowLayout {
            visible: !SpeedtestState.running && SpeedtestState.pingMs >= 0
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: [
                    { glyph: "\uf1ae", label: "ping", val: SpeedtestState.pingMs >= 0 ? SpeedtestState.pingMs.toFixed(0) + " ms" : "—", tint: "#f1fa8c" },
                    { glyph: "\uf019", label: "down", val: SpeedtestState.downMbps >= 0 ? SpeedtestState.downMbps.toFixed(1) + " Mbps" : "—", tint: "#50fa7b" },
                    { glyph: "\uf093", label: "up", val: SpeedtestState.upMbps > 0 ? SpeedtestState.upMbps.toFixed(1) + " Mbps" : "—", tint: "#ff79c6" }
                ]

                delegate: ColumnLayout {
                    id: resCell

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: resCell.modelData.glyph + " " + resCell.modelData.val
                        color: resCell.modelData.tint
                        font { pixelSize: 13; bold: true; family: "ZedMono Nerd Font" }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: resCell.modelData.label
                        color: "#6272a4"
                        font { pixelSize: 8; bold: true; family: "Quicksand"; letterSpacing: 2 }
                    }
                }
            }
        }

        // ── error line ──
        Text {
            visible: SpeedtestState.error.length > 0
            Layout.fillWidth: true
            text: "" + SpeedtestState.error
            color: "#ff5555"
            elide: Text.ElideRight
            font { pixelSize: 9; family: "ZedMono Nerd Font" }
        }
    }

    property real wobble: 0
}
