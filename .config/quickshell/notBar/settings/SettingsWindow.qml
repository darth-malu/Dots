import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import qs.customItems
import qs.services
import qs.bar.quicksettings.nowplaying
import Quickshell.Services.Mpris
import Quickshell.Networking

Item {
    id: root

    property int currentCategory: 0

    // ── shared switch pill — one control, one look, everywhere ──
    component SwitchPill: Rectangle {
        id: sp

        property bool on: false
        signal toggled()

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 36
        implicitHeight: 20
        radius: 10
        color: on ? "#bd93f9" : "#44475a"

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: "#282a36"
            x: sp.on ? parent.width - width - 2 : 2
            y: (parent.height - height) / 2

            Behavior on x {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sp.toggled()
        }
    }

    // ── single-line setting row: glyph · label · (state caption) · switch ──
    component SettingRow: RowLayout {
        id: sr

        required property string icon
        required property string label
        property string caption
        property bool checked
        signal flipped()

        spacing: 12
        Layout.fillWidth: true
        Layout.preferredHeight: 38

        Text {
            text: sr.icon
            color: sr.checked ? "#bd93f9" : "#6272a4"
            font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: sr.label
            color: "#f8f8f2"
            font { pixelSize: 12; family: "Quicksand"; bold: true }
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: sr.caption.length > 0
            text: sr.caption
            color: sr.checked ? "#bd93f9" : "#6272a4"
            font { pixelSize: 10; family: "ZedMono Nerd Font" }
            Layout.alignment: Qt.AlignVCenter
        }

        SwitchPill {
            on: sr.checked
            onToggled: sr.flipped()
        }
    }

    // ── one clickable / holdable arrow button ──
    component StepBtn: Rectangle {
        id: sb

        property string glyph
        signal stepped()

        implicitWidth: 24
        implicitHeight: 24
        radius: 7
        color: sbMa.containsMouse || sbMa.pressed ? Qt.rgba(0.74, 0.58, 0.98, 0.16) : "#343746"
        border.width: 1
        border.color: sbMa.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.45) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 110 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 110 }
        }

        Text {
            anchors.centerIn: parent
            text: sb.glyph
            color: sbMa.pressed ? "#bd93f9" : sbMa.containsMouse ? "#f8f8f2" : "#b8bfcb"
            font {
                pixelSize: 11
                bold: true
                family: "Symbols Nerd Font Mono"
            }

            Behavior on color {
                ColorAnimation { duration: 110 }
            }
        }

        MouseArea {
            id: sbMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // step immediately, then repeat while held
            onPressed: {
                sb.stepped();
                sbHold.restart();
            }
            onReleased: sbHold.stop()
            onCanceled: sbHold.stop()

            Timer {
                id: sbHold
                interval: 400
                repeat: true
                running: false
                onTriggered: sb.stepped()
            }
        }
    }

    // ── poll-rate stepper row: glyph · label · [−] value [+] ──
    component PollRow: RowLayout {
        id: pr

        required property string icon
        required property string label
        required property int minMs
        required property int maxMs
        required property int stepMs
        property int valueMs
        // fired whenever the value changes
        signal committed(int ms)

        function nudge(dir) {
            const v = Math.max(minMs, Math.min(maxMs, valueMs + dir * stepMs));
            if (v === valueMs)
                return;
            valueMs = v;
            committed(v);
        }

        spacing: 12
        Layout.fillWidth: true
        Layout.preferredHeight: 34

        Text {
            text: pr.icon
            color: "#bd93f9"
            font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: pr.label
            color: "#f8f8f2"
            font { pixelSize: 12; family: "Quicksand"; bold: true }
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        StepBtn {
            glyph: "\uf068"
            Layout.alignment: Qt.AlignVCenter
            onStepped: pr.nudge(-1)
        }

        // live value readout — scroll over it to adjust
        Rectangle {
            id: valBox

            implicitWidth: 58
            implicitHeight: 24
            radius: 7
            color: valHover.containsMouse ? "#2a2c3a" : "#21222c"
            border.width: 1
            border.color: valHover.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.5) : "#313244"

            Behavior on color {
                ColorAnimation { duration: 110 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 110 }
            }

            HoverHandler {
                id: valHover
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: ev => {
                    pr.nudge(ev.angleDelta.y > 0 ? 1 : -1);
                    ev.accepted = true;
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.fmtMs(pr.valueMs)
                color: valHover.containsMouse ? "#f8f8f2" : "#bd93f9"
                font { pixelSize: 11; bold: true; family: "ZedMono Nerd Font" }

                Behavior on color {
                    ColorAnimation { duration: 110 }
                }
            }
        }

        StepBtn {
            glyph: "\uf067"
            Layout.alignment: Qt.AlignVCenter
            onStepped: pr.nudge(1)
        }
    }

    function fmtMs(ms) {
        if (ms >= 1000) {
            const s = Math.round(ms / 100) / 10;
            return (Number.isInteger(s) ? s : s.toFixed(1)) + "s";
        }
        return ms + "ms";
    }

    readonly property var categories: [
        { icon: "\uf080", label: "Bar" },
        { icon: "\uf144", label: "Media" },
        { icon: "\uf1eb", label: "Connections" },
        { icon: "\uf2db", label: "Performance" },
    ]

    readonly property string hostName: QuickState.hostName

    property string activeInterface: ""
    readonly property string netState: {
        var raw = netFile.text().trim();
        return raw.length > 0 ? raw : "down";
    }
    readonly property bool isOnline: root.netState === "up"

    FileView {
        id: netFile
        path: root.activeInterface.length > 0 ? `file:///sys/class/net/${root.activeInterface}/operstate` : ""
    }

    Process {
        id: interfaceCheck
        running: false
        command: ["sh", "-c", "ip -o route show default 2>/dev/null | head -1 | awk '{print $5}'"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0)
                    root.activeInterface = data.trim();
            }
        }
    }


    Timer {
        id: infoTimer
        interval: 15000
        running: MiscState.toggleSettings
        repeat: true
        onTriggered: {
            interfaceCheck.running = true;
        }
    }

    PanelWindow {
        id: window

        visible: MiscState.toggleSettings

        onVisibleChanged: {
            if (visible) {
                interfaceCheck.running = true;
            }
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        color: "transparent"

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        contentItem {
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    MiscState.toggleSettings = false;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#60000000"

            MouseArea {
                anchors.fill: parent
                onClicked: MiscState.toggleSettings = false
            }

            Rectangle {
                implicitWidth: 880
                implicitHeight: 640

                anchors.centerIn: parent

                radius: 16
                color: "#282a36"
                border.width: 1
                border.color: "#3b3f51"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {} // consume clicks to prevent closing
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 1
                    spacing: 0

                    Rectangle {
                        Layout.preferredWidth: 220
                        Layout.fillHeight: true
                        radius: 16
                        color: "#21222c"

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: 8
                                topMargin: 16
                            }
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: 12
                                Layout.bottomMargin: 12
                                text: "Settings"
                                color: "#f8f8f2"
                                font {
                                    pixelSize: 16
                                    bold: true
                                    family: "Quicksand"
                                }
                            }

                            Repeater {
                                model: root.categories

                                Rectangle {
                                    required property int index
                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    radius: 8
                                    color: root.currentCategory === index
                                        ? Qt.rgba(0.54, 0.57, 0.96, 0.15)
                                        : "transparent"

                                    Behavior on color {
                                        ColorAnimation { duration: 100 }
                                    }

                                    RowLayout {
                                        anchors {
                                            left: parent.left
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 12
                                        }
                                        spacing: 10

                                        Text {
                                            text: modelData.icon
                                            color: root.currentCategory === index ? "#bd93f9" : "#6272a4"
                                            font {
                                                pixelSize: 14
                                                family: "Symbols Nerd Font Mono"
                                            }
                                        }

                                        Text {
                                            text: modelData.label
                                            color: root.currentCategory === index ? "#f8f8f2" : "#b8bfcb"
                                            font {
                                                pixelSize: 12
                                                family: "Quicksand"
                                                bold: root.currentCategory === index
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.currentCategory = index
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"

                        Item {
                            anchors {
                                fill: parent
                                margins: 24
                                topMargin: 28
                            }

                            Flickable {
                                anchors.fill: parent
                                contentWidth: parent.width
                                contentHeight: pageLoader.implicitHeight + 8
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

                                Loader {
                                    id: pageLoader
                                    width: parent.width
                                    sourceComponent: root.currentCategory === 0 ? barPage
                                        : root.currentCategory === 1 ? mediaPage
                                        : root.currentCategory === 2 ? connectionsPage
                                        : performancePage
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══ BAR ═══
        Component {
            id: barPage

            ColumnLayout {
                spacing: 12

                Card {
                    title: "Style"
                    icon: ""
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        // segmented style selector — pick the bar
                        // treatment directly instead of an on/off switch
                        RowLayout {
                            id: barStyleSeg

                            readonly property int mode: BarState.barMode

                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            spacing: 12

                            Text {
                                text: "\ueac1"
                                color: "#bd93f9"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                text: "Bar style"
                                color: "#f8f8f2"
                                font { pixelSize: 12; family: "Quicksand"; bold: true }
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: segRow.implicitWidth + 6
                                implicitHeight: 26
                                radius: 8
                                color: "#21222c"
                                border.width: 1
                                border.color: "#313244"

                                Row {
                                    id: segRow

                                    anchors.centerIn: parent
                                    spacing: 2

                                    Repeater {
                                        model: [
                                            { key: 0, label: "Transparent" },
                                            { key: 1, label: "Solid" },
                                            { key: 2, label: "Full" }
                                        ]

                                        delegate: Rectangle {
                                            id: segOpt

                                            required property var modelData

                                            readonly property bool sel: barStyleSeg.mode === segOpt.modelData.key

                                            width: segLbl.implicitWidth + 20
                                            height: 22
                                            radius: 6
                                            color: sel ? "#bd93f9" : segOptMa.containsMouse ? Qt.rgba(0.741, 0.576, 0.976, 0.14) : "transparent"

                                            Behavior on color {
                                                ColorAnimation { duration: 120 }
                                            }

                                            Text {
                                                id: segLbl

                                                anchors.centerIn: parent
                                                text: segOpt.modelData.label
                                                color: segOpt.sel ? "#181825" : segOptMa.containsMouse ? "#f8f8f2" : "#b8bfcb"
                                                font { pixelSize: 10; bold: true; family: "Quicksand" }

                                                Behavior on color {
                                                    ColorAnimation { duration: 120 }
                                                }
                                            }

                                            MouseArea {
                                                id: segOptMa

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: BarState.barMode = segOpt.modelData.key
                            }
                        }
                    }
                }
            }
        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf009"
                            label: "Icon workspaces"
                            caption: MiscState.iconWorkspaces ? "app icons" : "numbers"
                            checked: MiscState.iconWorkspaces
                            onFlipped: MiscState.iconWorkspaces = !MiscState.iconWorkspaces
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\ueb7c"
                            label: "Popup background"
                            caption: MiscState.popupSolidBg ? "solid" : "transparent"
                            checked: MiscState.popupSolidBg
                            onFlipped: MiscState.popupSolidBg = !MiscState.popupSolidBg
                        }
                    }
                }

                Card {
                    title: "Bar Modules"
                    icon: "\uf132"
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        Repeater {
                            model: [
                                { icon: "\uf028", label: "Volume output", key: "showVolumeOut" },
                                { icon: "\uf130", label: "Microphone input", key: "showVolumeIn" },
                                { icon: "\uf293", label: "Bluetooth", key: "showBluetooth" },
                                { icon: "\uf1eb", label: "Wi-Fi", key: "showWifi" },
                                { icon: "\uf1e6", label: "Ethernet", key: "showEthernet" },
                                { icon: "\uf240", label: "Battery", key: "showBattery" },
                                { icon: "\uf0a2", label: "Notifications", key: "showNotifTray" }
                            ]

                            delegate: ColumnLayout {
                                id: modCell

                                required property var modelData
                                required property int index

                                spacing: 0
                                Layout.fillWidth: true

                                SettingRow {
                                    icon: modCell.modelData.icon
                                    label: modCell.modelData.label
                                    checked: MiscState[modCell.modelData.key]
                                    onFlipped: MiscState[modCell.modelData.key] = !MiscState[modCell.modelData.key]
                                }

                                // separator between module rows
                                Rectangle {
                                    visible: modCell.index < 6
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#343746"
                                    Layout.leftMargin: 32
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══ MEDIA ═══
        Component {
            id: mediaPage

            ColumnLayout {
                spacing: 12

                Card {
                    title: "MPRIS"
                    icon: ""
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        SettingRow {
                            icon: "\uf03e"
                            label: "Album art"
                            checked: MprisState.mprisArtVisible
                            onFlipped: MprisState.mprisArtVisible = !MprisState.mprisArtVisible
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\ue01c"
                            label: "Progress ring"
                            checked: MprisState.showMprisProgress
                            onFlipped: MprisState.showMprisProgress = !MprisState.showMprisProgress
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\ue03c"
                            label: "Hide when idle"
                            checked: MprisState.hideWhenIdle
                            onFlipped: MprisState.hideWhenIdle = !MprisState.hideWhenIdle
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf07c"
                            label: "Marquee titles"
                            checked: MprisState.marqueeEnabled
                            onFlipped: MprisState.marqueeEnabled = !MprisState.marqueeEnabled
                        }
                    }
                }

                Card {
                    title: "Now Playing"
                    icon: ""
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        SettingRow {
                            icon: "\uf2d1"
                            label: "Player chooser"
                            checked: MiscState.showPlayerChooser
                            onFlipped: MiscState.showPlayerChooser = !MiscState.showPlayerChooser
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf074"
                            label: "Shuffle button"
                            checked: MiscState.showShuffle
                            onFlipped: MiscState.showShuffle = !MiscState.showShuffle
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf079"
                            label: "Loop button"
                            checked: MiscState.showLoop
                            onFlipped: MiscState.showLoop = !MiscState.showLoop
                        }
                    }
                }
            }
        }

        // ═══ CONNECTIONS ═══
        Component {
            id: connectionsPage

            ColumnLayout {
                spacing: 12

                // ── live status tiles ──
                RowLayout {
                    spacing: 12
                    Layout.fillWidth: true

                    Rectangle {
                        id: wifiTile

                        Layout.fillWidth: true
                        implicitHeight: 74
                        radius: 10
                        color: "#21222c"
                        border.width: 1
                        border.color: NetworkState.wifiConnected ? Qt.rgba(0.741, 0.576, 0.976, 0.4) : "#313244"

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            IconImage {
                                Layout.alignment: Qt.AlignHCenter
                                source: NetworkState.wifiIcon
                                implicitSize: 22
                                asynchronous: true
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: {
                                    const n = NetworkState.activeNetwork?.name;
                                    return NetworkState.wifiConnected && n ? n : "Wi-Fi off";
                                }
                                color: NetworkState.wifiConnected ? "#f8f8f2" : "#6272a4"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font { pixelSize: 11; bold: true; family: "Quicksand" }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: NetworkState.adapter?.connected
                                    ? "signal " + Math.round(NetworkState.activeNetwork?.strength ?? 0) + "%"
                                    : NetworkState.wifiEnabled ? "idle" : "disabled"
                                color: "#6272a4"
                                font { pixelSize: 9; family: "ZedMono Nerd Font" }
                            }
                        }
                    }

                    Rectangle {
                        id: ethTile

                        Layout.fillWidth: true
                        implicitHeight: 74
                        radius: 10
                        color: "#21222c"
                        border.width: 1
                        border.color: NetworkState.ethernet?.hasLink ? Qt.rgba(0.545, 0.914, 0.992, 0.4) : "#313244"

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            IconImage {
                                Layout.alignment: Qt.AlignHCenter
                                source: NetworkState.ethIcon
                                implicitSize: 22
                                asynchronous: true
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: NetworkState.ethernet?.hasLink ? "Ethernet" : "No cable"
                                color: NetworkState.ethernet?.hasLink ? "#f8f8f2" : "#6272a4"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font { pixelSize: 11; bold: true; family: "Quicksand" }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: NetworkState.ethernet?.hasLink ? "link up" : "disconnected"
                                color: "#6272a4"
                                font { pixelSize: 9; family: "ZedMono Nerd Font" }
                            }
                        }
                    }
                }

                Card {
                    title: "Preferences"
                    icon: "\uf013"
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        SettingRow {
                            icon: "\uf1eb"
                            label: "Connected highlight"
                            caption: MiscState.wifiGreenName ? "green name" : "classic"
                            checked: MiscState.wifiGreenName
                            onFlipped: MiscState.wifiGreenName = !MiscState.wifiGreenName
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf796"
                            label: "Session totals"
                            caption: MiscState.showNetTotals ? "always visible" : "with graphs"
                            checked: MiscState.showNetTotals
                            onFlipped: MiscState.showNetTotals = !MiscState.showNetTotals
                        }
                    }
                }

                Card {
                    title: "Bar modules"
                    icon: "\ueac1"
                    accent: "#8be9fd"

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        SettingRow {
                            icon: "\uf1eb"
                            label: "Wi-Fi module"
                            checked: MiscState.showWifi
                            onFlipped: MiscState.showWifi = !MiscState.showWifi
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf796"
                            label: "Ethernet module"
                            checked: MiscState.showEthernet
                            onFlipped: MiscState.showEthernet = !MiscState.showEthernet
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf294"
                            label: "Bluetooth module"
                            checked: MiscState.showBluetooth
                            onFlipped: MiscState.showBluetooth = !MiscState.showBluetooth
                        }
                    }
                }
            }
        }

        // ═══ PERFORMANCE ═══
        Component {
            id: performancePage

            ColumnLayout {
                spacing: 12

                Card {
                    title: "Poll Rates"
                    icon: "\uf2db"
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 14
                        Layout.fillWidth: true
                        Layout.topMargin: 4

                        PollRow {
                            icon: "\uf4bc"
                            label: "CPU · Memory"
                            minMs: 500
                            maxMs: 10000
                            stepMs: 250
                            valueMs: ResourcesState.cpuMemInterval
                            onCommitted: ms => ResourcesState.cpuMemInterval = ms
                        }

                        PollRow {
                            icon: "\uf1eb"
                            label: "Network speed"
                            minMs: 250
                            maxMs: 5000
                            stepMs: 250
                            valueMs: NetworkState.netInterval
                            onCommitted: ms => NetworkState.netInterval = ms
                        }

                        PollRow {
                            icon: "\uf0a0"
                            label: "Disk usage"
                            minMs: 5000
                            maxMs: 60000
                            stepMs: 5000
                            valueMs: ResourcesState.diskInterval
                            onCommitted: ms => ResourcesState.diskInterval = ms
                        }

                        PollRow {
                            icon: "\uf240"
                            label: "Battery history"
                            minMs: 10000
                            maxMs: 120000
                            stepMs: 5000
                            valueMs: BatteryState.batteryInterval
                            onCommitted: ms => BatteryState.batteryInterval = ms
                        }
                    }
                }

                Card {
                    title: "Notes"
                    icon: "\uf05a"
                    accent: "#8be9fd"

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true
                        Layout.topMargin: 2

                        Text {
                            Layout.fillWidth: true
                            text: "· Lower rates feel snappier, higher rates save battery."
                            color: "#b8bfcb"
                            font { pixelSize: 11; family: "ZedMono Nerd Font" }
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "· Values persist across config reloads."
                            color: "#b8bfcb"
                            font { pixelSize: 11; family: "ZedMono Nerd Font" }
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
