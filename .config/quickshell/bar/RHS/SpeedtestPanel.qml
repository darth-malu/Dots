import QtQuick
import QtQuick.Layouts
import qs.services

// Speed-test card — result tiles (ping / down / up) light up one-by-one,
// a three-segment phase track fills live, and a collapsible details row
// shows test parameters after completion.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: contentCol.implicitHeight + 20
    radius: 10
    color: Qt.rgba(1, 1, 1, 0.03)
    border.width: 1
    border.color: "#343746"

    readonly property bool running: SpeedtestState.running
    readonly property bool showDetails: !running && SpeedtestState.pingMs >= 0

    // 0..3 — how many of ping/down/up have landed
    readonly property int stage: {
        let s = 0;
        if (SpeedtestState.pingMs >= 0)
            s++;
        if (SpeedtestState.downMbps >= 0)
            s++;
        if (SpeedtestState.upMbps >= 0)
            s++;
        return s;
    }

    function _val(i) {
        if (!running && SpeedtestState.error.length > 0)
            return "—";
        if (i === 0)
            return SpeedtestState.pingMs >= 0 ? SpeedtestState.pingMs.toFixed(0) : "";
        if (i === 1)
            return SpeedtestState.downMbps >= 0 ? SpeedtestState.downMbps.toFixed(1) : "";
        return SpeedtestState.upMbps >= 0 ? SpeedtestState.upMbps.toFixed(1) : "";
    }

    ColumnLayout {
        id: contentCol

        anchors {
            fill: parent
            margins: 12
        }
        spacing: 9

        // ── header: identity + action ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 8
                color: Qt.rgba(0.741, 0.576, 0.976, 0.12)

                Text {
                    anchors.centerIn: parent
                    text: "\uf0e4"
                    color: "#bd93f9"
                    font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                }
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Speed test"
                    color: "#f8f8f2"
                    font { pixelSize: 12; bold: true; family: "Quicksand" }
                }

                Text {
                    text: {
                        if (root.running) {
                            const p = SpeedtestState.phase;
                            const pct = Math.round(SpeedtestState.progress * 100);
                            return (p === "ping" ? "measuring latency"
                                : p === "down" ? "downloading"
                                : p === "up" ? "uploading" : "starting") + " · " + pct + "%";
                        }
                        if (SpeedtestState.error.length > 0)
                            return SpeedtestState.error;
                        if (SpeedtestState.pingMs >= 0) {
                            const s = SpeedtestState.server;
                            const mb = SpeedtestState.totalMB.toFixed(1);
                            const sec = Math.round(SpeedtestState.testDuration);
                            let info = "done";
                            if (s.length > 0)
                                info += " · " + s;
                            if (mb > 0)
                                info += " · " + mb + " MB in " + sec + "s";
                            return info;
                        }
                        return "Cloudflare edge · ~30 s";
                    }
                    color: root.running ? "#bd93f9" : SpeedtestState.error.length > 0 ? "#ff5555" : "#6272a4"
                    font { pixelSize: 9; family: "ZedMono Nerd Font" }

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: actionBtn

                implicitWidth: 74
                implicitHeight: 28
                radius: 14
                color: {
                    if (actionMa.containsMouse)
                        return root.running ? Qt.rgba(1, 0.33, 0.33, 0.2) : Qt.rgba(0.741, 0.576, 0.976, 0.26);
                    return root.running ? Qt.rgba(1, 0.33, 0.33, 0.1) : Qt.rgba(0.741, 0.576, 0.976, 0.14);
                }
                border.width: 1
                border.color: root.running ? Qt.rgba(1, 0.33, 0.33, 0.4) : Qt.rgba(0.741, 0.576, 0.976, 0.45)

                Behavior on color {
                    ColorAnimation { duration: 130 }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: root.running ? "\uf04d" : "\uf052"
                        color: root.running ? "#ff5555" : "#bd93f9"
                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                    }

                    Text {
                        text: root.running ? "Stop" : "Start"
                        color: "#f8f8f2"
                        font { pixelSize: 11; bold: true; family: "Quicksand" }
                    }
                }

                MouseArea {
                    id: actionMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.running ? SpeedtestState.cancel() : SpeedtestState.start()
                }
            }
        }

        // ── result tiles ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { glyph: "\uf1ae", label: "PING", unit: "ms", tint: Qt.color("#f1fa8c"), phase: "ping" },
                    { glyph: "\uf019", label: "DOWN", unit: "Mbps", tint: Qt.color("#50fa7b"), phase: "down" },
                    { glyph: "\uf093", label: "UP", unit: "Mbps", tint: Qt.color("#ff79c6"), phase: "up" }
                ]

                delegate: Rectangle {
                    id: tile

                    required property var modelData
                    readonly property int idx: index
                    readonly property bool isNext: root.running && SpeedtestState.phase === tile.modelData.phase
                    readonly property bool landed: root.stage > tile.idx
                    readonly property string valStr: root._val(tile.idx)

                    Layout.fillWidth: true
                    implicitHeight: 58
                    radius: 9
                    color: landed || isNext ? Qt.rgba(tile.modelData.tint.r, tile.modelData.tint.g, tile.modelData.tint.b, isNext ? 0.1 : 0.06) : Qt.rgba(1, 1, 1, 0.02)
                    border.width: 1
                    border.color: isNext ? Qt.rgba(tile.modelData.tint.r, tile.modelData.tint.g, tile.modelData.tint.b, 0.55) : "#313244"

                    Behavior on border.color { ColorAnimation { duration: 180 } }
                    Behavior on color { ColorAnimation { duration: 180 } }

                    SequentialAnimation on opacity {
                        running: tile.isNext
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.72; duration: 420 }
                        NumberAnimation { to: 1; duration: 420 }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Text {
                                text: tile.modelData.glyph
                                color: tile.landed || tile.isNext ? tile.modelData.tint : "#6272a4"
                                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Text {
                                text: tile.modelData.label
                                color: "#6272a4"
                                font { pixelSize: 8; bold: true; letterSpacing: 2; family: "Quicksand" }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 3

                            Text {
                                text: tile.valStr.length > 0 ? tile.valStr : "—"
                                color: tile.valStr.length > 0 ? "#f8f8f2" : "#44475a"
                                font { pixelSize: 17; weight: Font.DemiBold; family: "ZedMono Nerd Font" }
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }

                            Text {
                                visible: tile.valStr.length > 0
                                text: tile.modelData.unit
                                color: "#6272a4"
                                font { pixelSize: 8; family: "ZedMono Nerd Font" }
                            }
                        }
                    }
                }
            }
        }

        // ── three-segment phase track — fills with real progress ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: ["ping", "down", "up"]

                delegate: Rectangle {
                    id: seg

                    required property int index
                    required property var modelData

                    readonly property bool active: root.running && SpeedtestState.phase === seg.modelData
                    readonly property real fill: root.stage > index ? 1
                        : active ? SpeedtestState.progress : 0

                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.06)
                    clip: true

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width * seg.fill
                        radius: 2
                        color: ["#f1fa8c", "#50fa7b", "#ff79c6"][seg.index]

                        Behavior on width {
                            NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
                        }

                        SequentialAnimation on opacity {
                            running: seg.active
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.75; duration: 380 }
                            NumberAnimation { to: 1; duration: 380 }
                        }
                    }
                }
            }
        }

        // ── test details — visible after completion ──
        Rectangle {
            Layout.fillWidth: true
            visible: root.showDetails
            implicitHeight: detCol.implicitHeight + 12
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.03)
            border.width: 1
            border.color: "#313244"

            ColumnLayout {
                id: detCol

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 6
                }
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "server"
                        color: "#6272a4"
                        font { pixelSize: 8; family: "Quicksand" }
                        Layout.preferredWidth: 56
                    }
                    Text {
                        text: SpeedtestState.server.length > 0 ? SpeedtestState.server : "—"
                        color: "#f8f8f2"
                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                        Layout.fillWidth: true
                    }

                    Item { width: 12 }

                    Text {
                        text: "probes"
                        color: "#6272a4"
                        font { pixelSize: 8; family: "Quicksand" }
                        Layout.preferredWidth: 42
                    }
                    Text {
                        text: "5 × best-of"
                        color: "#f8f8f2"
                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "data"
                        color: "#6272a4"
                        font { pixelSize: 8; family: "Quicksand" }
                        Layout.preferredWidth: 56
                    }
                    Text {
                        text: SpeedtestState.totalMB > 0 ? SpeedtestState.totalMB.toFixed(1) + " MB" : "—"
                        color: "#f8f8f2"
                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                        Layout.fillWidth: true
                    }

                    Item { width: 12 }

                    Text {
                        text: "down"
                        color: "#6272a4"
                        font { pixelSize: 8; family: "Quicksand" }
                        Layout.preferredWidth: 42
                    }
                    Text {
                        text: "5 × 10 MB"
                        color: "#f8f8f2"
                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "duration"
                        color: "#6272a4"
                        font { pixelSize: 8; family: "Quicksand" }
                        Layout.preferredWidth: 56
                    }
                    Text {
                        text: SpeedtestState.testDuration > 0 ? Math.round(SpeedtestState.testDuration) + "s" : "—"
                        color: "#f8f8f2"
                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                        Layout.fillWidth: true
                    }

                    Item { width: 12 }

                    Text {
                        text: "up"
                        color: "#6272a4"
                        font { pixelSize: 8; family: "Quicksand" }
                        Layout.preferredWidth: 42
                    }
                    Text {
                        text: "3 × 3 MB"
                        color: "#f8f8f2"
                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                    }
                }
            }
        }
    }
}
