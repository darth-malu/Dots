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
import qs.bar.RHS
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
        { icon: "\uf059", label: "Help" },
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
                                    : root.currentCategory === 3 ? performancePage
                                    : helpPage
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
                                            { key: 2, label: "Full" },
                                            { key: 3, label: "Glass" }
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
                            icon: "\uf1ce"
                            label: "Show workspaces"
                            caption: MiscState.showWorkspaces ? "on" : "off"
                            checked: MiscState.showWorkspaces
                            onFlipped: MiscState.showWorkspaces = !MiscState.showWorkspaces
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf009"
                            label: "Show icons"
                            caption: MiscState.iconWorkspaces ? "on" : "off"
                            checked: MiscState.iconWorkspaces
                            onFlipped: MiscState.iconWorkspaces = !MiscState.iconWorkspaces
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf2d1"
                            label: "Boxy design"
                            caption: MiscState.boxyTheme ? "boxy" : "rounded"
                            checked: MiscState.boxyTheme
                            onFlipped: MiscState.boxyTheme = !MiscState.boxyTheme
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf070"
                            label: "Popup background"
                            caption: MiscState.popupSolidBg ? "solid" : "transparent"
                            checked: MiscState.popupSolidBg
                            onFlipped: MiscState.popupSolidBg = !MiscState.popupSolidBg
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf290"
                            label: "Boxy system tray"
                            caption: MiscState.boxyTray ? "coloured pill" : "glass"
                            checked: MiscState.boxyTray
                            onFlipped: MiscState.boxyTray = !MiscState.boxyTray
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            spacing: 12

                            Text {
                                text: "\uf031"
                                color: "#6272a4"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                text: "Notification font"
                                color: "#f8f8f2"
                                font { pixelSize: 12; family: "Quicksand"; bold: true }
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            Repeater {
                                model: ["Quicksand", "ZedMono Nerd Font", "Nunito", "Lato"]

                                Rectangle {
                                    id: notifFontOpt

                                    required property string modelData

                                    readonly property bool sel: MiscState.notifFont === notifFontOpt.modelData

                                    width: notifFontLbl.implicitWidth + 16
                                    height: 22
                                    radius: 6
                                    color: notifFontOpt.sel ? "#bd93f9" : notifFontMa.containsMouse ? Qt.rgba(0.741, 0.576, 0.976, 0.14) : "transparent"

                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    Text {
                                        id: notifFontLbl

                                        anchors.centerIn: parent
                                        text: notifFontOpt.modelData
                                        color: notifFontOpt.sel ? "#181825" : notifFontMa.containsMouse ? "#f8f8f2" : "#b8bfcb"
                                        font { pixelSize: 10; bold: true; family: "Quicksand" }

                                        Behavior on color {
                                            ColorAnimation { duration: 120 }
                                        }
                                    }

                                    MouseArea {
                                        id: notifFontMa

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: MiscState.notifFont = notifFontOpt.modelData
                                    }
                                }
                            }
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
                            icon: "\uf1ce"
                            label: "Progress ring"
                            checked: MprisState.showMprisProgress
                            onFlipped: MprisState.showMprisProgress = !MprisState.showMprisProgress
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                        SettingRow {
                            icon: "\uf070"
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
                id: connPage

                spacing: 12

                // which half of the connections page is showing
                property int connTab: 0

                // ── tab strip · network | speedtest ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    component ConnTab: Rectangle {
                        id: ctab

                        property string label
                        property string glyph
                        property int idx

                        readonly property bool active: connPage.connTab === ctab.idx
                        readonly property bool hovered: tabMa.containsMouse

                        Layout.preferredHeight: 26
                        implicitWidth: tabRow.implicitWidth + 18
                        radius: 8
                        color: active ? Qt.rgba(0.74, 0.58, 0.98, 0.16) : hovered ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.03)
                        border.width: 1
                        border.color: active ? Qt.rgba(0.74, 0.58, 0.98, 0.5) : Qt.rgba(1, 1, 1, 0.07)

                        Behavior on color {
                            ColorAnimation { duration: 110 }
                        }

                        Row {
                            id: tabRow

                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ctab.glyph
                                color: ctab.active ? "#e2d6fb" : "#8b93b8"
                                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ctab.label
                                color: ctab.active ? "#f8f8f2" : "#8b93b8"
                                font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 1 }
                            }
                        }

                        MouseArea {
                            id: tabMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connPage.connTab = ctab.idx
                        }
                    }

                    ConnTab { label: "Network"; glyph: "\uf1eb"; idx: 0 }
                    ConnTab { label: "Speedtest"; glyph: "\uf1fe"; idx: 1 }

                    Item { Layout.fillWidth: true }
                }

                StackLayout {
                    Layout.fillWidth: true
                    currentIndex: connPage.connTab

                    // ── tab · network ──
                    ColumnLayout {
                        spacing: 12

                    Card {
                        title: "Connections"
                        icon: "\uf1eb"
                        accent: "#bd93f9"

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            // omarchy-quattro style: one quiet row per interface —
                            // glyph · name/state · live caption · switch
                            SettingRow {
                                icon: "\uf1eb"
                                label: {
                                    const ssid = NetworkState.activeNetwork?.name ?? "";
                                    if (!NetworkState.wifiEnabled)
                                        return "Wi-Fi";
                                    return NetworkState.wifiConnected && ssid.length > 0 ? ssid : "Wi-Fi";
                                }
                                caption: !NetworkState.wifiEnabled ? "radio off"
                                    : NetworkState.wifiConnected ? Math.round((NetworkState.activeNetwork?.signalStrength ?? 0) * 100) + "% signal"
                                    : "scanning…"
                                checked: NetworkState.wifiEnabled
                                onFlipped: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                            SettingRow {
                                icon: "\uef44"
                                label: ["Ethernet off", "No carrier", "Ethernet"][NetworkState.ethernet?.hasLink ? 2 : NetworkState.ethernet?.connected ? 1 : 0]
                                caption: NetworkState.ethernet?.hasLink ? "link up" : NetworkState.ethernet?.connected ? "cable detected" : "disconnected"
                                checked: NetworkState.ethernet?.hasLink || false
                                onFlipped: NetworkState.setEthernetEnabled(!(NetworkState.ethernet?.hasLink || false))
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 32 }

                            SettingRow {
                                icon: "\uf294"
                                label: Bt.enabled ? (Bt.connected && Bt.btDev.length > 0 ? Bt.btDev : "Bluetooth") : "Bluetooth"
                                caption: !Bt.enabled ? "radio off" : Bt.connected ? "connected" + (Bt.btBat > 0 ? " · " + Math.round(Bt.btBat * 100) + "%" : "") : "no devices"
                                checked: Bt.enabled
                                onFlipped: {
                                    if (Bt.adapter)
                                        Bt.adapter.enabled = !Bt.adapter.enabled;
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
                                icon: "\uf1fe"
                                label: "Session totals"
                                caption: MiscState.showNetTotals ? "always visible" : "with graphs"
                                checked: MiscState.showNetTotals
                                onFlipped: MiscState.showNetTotals = !MiscState.showNetTotals
                            }
                        }
                    }
                    }

                    // ── tab · speedtest ──
                    ColumnLayout {
                        spacing: 12

                        SpeedtestPanel {}

                        Card {
                            title: "History"
                            icon: "\uf1fe"
                            accent: "#8be9fd"

                            ColumnLayout {
                                spacing: 7
                                Layout.fillWidth: true

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: "last " + SpeedtestState.history.length + " runs"
                                        color: "#6272a4"
                                        font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        visible: SpeedtestState.history.length > 0
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        radius: 6
                                        color: hClearMa.containsMouse ? Qt.rgba(1, 0.33, 0.33, 0.16) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf1f8"
                                            color: hClearMa.containsMouse ? "#ff5555" : "#6272a4"
                                            font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                        }

                                        MouseArea {
                                            id: hClearMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: SpeedtestState.clearHistory()
                                        }
                                    }
                                }

                                Repeater {
                                    model: SpeedtestState.history

                                    delegate: Rectangle {
                                        id: hrow

                                        required property int index
                                        required property var modelData

                                        Layout.fillWidth: true
                                        implicitHeight: hrowCol.implicitHeight + 14
                                        radius: 8
                                        color: hrowHover.containsMouse ? Qt.rgba(0.741, 0.576, 0.976, 0.12) : "transparent"

                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        MouseArea {
                                            id: hrowHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            z: -1
                                        }

                                        readonly property var d: new Date(hrow.modelData.ts * 1000)
                                        readonly property real dv: hrow.modelData.down ?? 0
                                        readonly property real uv: hrow.modelData.up ?? 0
                                        readonly property real pv: hrow.modelData.ping ?? 0
                                        readonly property string srv: hrow.modelData.server ?? ""

                                        function _fmt(when) {
                                            const mo = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][when.getMonth()];
                                            const hh = String(when.getHours()).padStart(2, "0");
                                            const mm = String(when.getMinutes()).padStart(2, "0");
                                            return mo + " " + when.getDate() + " · " + hh + ":" + mm;
                                        }

                                        ColumnLayout {
                                            id: hrowCol
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 7 }
                                            spacing: 5

                                            // ── line 1: time + network + metrics ──
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text {
                                                    text: hrow._fmt(hrow.d)
                                                    color: "#b8bfcb"
                                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                                    Layout.preferredWidth: 88
                                                }

                                                Row {
                                                    spacing: 4
                                                    visible: hrow.modelData.net.length > 0

                                                    Text {
                                                        text: hrow.modelData.net === "Ethernet" ? "\uef44" : "\uf1eb"
                                                        color: hrow.modelData.net === "Ethernet" ? "#8be9fd" : "#bd93f9"
                                                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                                    }

                                                    Text {
                                                        text: hrow.modelData.net
                                                        color: hrow.index === 0 ? "#f8f8f2" : "#b8bfcb"
                                                        elide: Text.ElideRight
                                                        font { pixelSize: 9; family: "Quicksand" }
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }

                                                Text {
                                                    text: hrow.pv.toFixed(0) + " ms"
                                                    color: "#f1fa8c"
                                                    font { pixelSize: 10; bold: true; family: "ZedMono Nerd Font" }
                                                    Layout.preferredWidth: 52
                                                    horizontalAlignment: Text.AlignRight
                                                }

                                                Text {
                                                    text: hrow.dv.toFixed(1)
                                                    color: "#50fa7b"
                                                    font { pixelSize: 10; bold: true; family: "ZedMono Nerd Font" }
                                                    Layout.preferredWidth: 40
                                                    horizontalAlignment: Text.AlignRight
                                                }

                                                Text {
                                                    text: hrow.uv > 0 ? hrow.uv.toFixed(1) : "—"
                                                    color: "#ff79c6"
                                                    font { pixelSize: 10; bold: true; family: "ZedMono Nerd Font" }
                                                    Layout.preferredWidth: 40
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }

                                            // ── line 2: speed bar ──
                                            Rectangle {
                                                Layout.fillWidth: true
                                                implicitHeight: 6
                                                radius: 3
                                                color: Qt.rgba(1, 1, 1, 0.06)

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width * Math.min(Math.max(hrow.dv, 0) / 150, 1)
                                                    radius: 3
                                                    color: hrow.dv > 80 ? "#50fa7b" : hrow.dv > 30 ? "#f1fa8c" : "#ffb86c"

                                                    Rectangle {
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 2.5; height: parent.height + 2; radius: 1.25
                                                        visible: hrow.dv > 4
                                                        color: hrow.dv > 80 ? "#50fa7b" : hrow.dv > 30 ? "#f1fa8c" : "#ffb86c"
                                                    }

                                                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                                                }
                                            }

                                            // ── line 3: server + duration (shown on hover) ──
                                            Text {
                                                visible: hrow.srv.length > 0 && hrowHover.containsMouse
                                                text: hrow.srv + " · " + Math.round(hrow.modelData.mb ?? 0) + " MB · " + (hrow.modelData.secs ?? 0) + "s"
                                                color: "#44475a"
                                                font { pixelSize: 8; family: "ZedMono Nerd Font" }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: SpeedtestState.history.length === 0
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 8
                                    text: "no runs yet"
                                    color: "#6272a4"
                                    font { pixelSize: 10; italic: true; family: "Quicksand" }
                                }
                            }
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

        // ═══ HELP ═══
        Component {
            id: helpPage

            component HelpTopic: Rectangle {
                id: topic

                property string glyph
                property string title
                property string summary
                default property alias body: bodyCol.children
                property bool open: false

                Layout.fillWidth: true
                // fixed-height header + snap height + fade: animating a size
                // bound to child implicit sizes jitters and clips mid-flight
                readonly property int headH: 34
                implicitHeight: 24 + headH + (topic.open ? 8 + bodyCol.implicitHeight : 0)
                radius: 10
                clip: true
                color: Qt.rgba(1, 1, 1, 0.02)
                border.width: 1
                border.color: topic.open ? Qt.rgba(0.741, 0.576, 0.976, 0.35) : "#343746"

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 8

                    RowLayout {
                        id: headRow

                        Layout.fillWidth: true
                        Layout.preferredHeight: topic.headH
                        spacing: 10

                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 8
                            color: Qt.rgba(0.741, 0.576, 0.976, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: topic.glyph
                                color: "#bd93f9"
                                font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: topic.title
                                color: "#f8f8f2"
                                elide: Text.ElideRight
                                font { pixelSize: 13; bold: true; family: "Quicksand" }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: !topic.open && topic.summary.length > 0
                                text: topic.summary
                                color: "#6272a4"
                                elide: Text.ElideRight
                                font { pixelSize: 10; family: "ZedMono Nerd Font" }
                            }
                        }

                        Text {
                            text: topic.open ? "\uf077" : "\uf078"
                            color: "#6272a4"
                            font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: topic.open = !topic.open
                        }
                    }

                    ColumnLayout {
                        id: bodyCol

                        visible: opacity > 0
                        opacity: topic.open ? 1 : 0
                        Layout.fillWidth: true
                        spacing: 6

                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }
                    }
                }
            }

            component HelpLine: Text {
                // bullet prefix applied on completion — bindings stay literal
                Component.onCompleted: text = "·  " + text
                Layout.fillWidth: true
                color: "#b8bfcb"
                wrapMode: Text.WordWrap
                font { pixelSize: 11; family: "Quicksand" }
            }

            component HelpCode: Rectangle {
                property string cmd

                Layout.fillWidth: true
                implicitHeight: codeTxt.implicitHeight + 14
                radius: 7
                color: "#181825"
                border.width: 1
                border.color: "#313244"

                Text {
                    id: codeTxt

                    anchors {
                        fill: parent
                        margins: 7
                    }
                    text: "$ " + parent.cmd
                    color: "#a6e3a1"
                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                    wrapMode: Text.WrapAnywhere
                }
            }

            ColumnLayout {
                spacing: 10

                HelpTopic {
                    glyph: "\uf0f3"
                    title: "Reminders"
                    summary: "calendar tasks · timed alerts · CLI"

                    HelpLine { text: "Click the clock in the bar to open the calendar popup." }
                    HelpLine { text: "Pick a day, then type your task in the input at the bottom." }
                    HelpLine { text: "The time field starts at the current hour — scroll or type on the HH/MM chips to adjust; every reminder is timed." }
                    HelpLine { text: "Dots on day cells show how many reminders are pending. The list under the calendar groups them by day — ✕ removes an entry." }
                    HelpLine { text: "When one is due you get a critical notification plus a chime. Reminders persist in ~/.config/quickshell/reminders.json." }
                    HelpLine { text: "You can also manage them from the terminal:" }
                    HelpCode { cmd: "qs -p ~/.config/quickshell ipc call reminders add \"Stand up\" 2026-08-25 09:00" }
                    HelpCode { cmd: "qs -p ~/.config/quickshell ipc call reminders list" }
                    HelpLine { text: "Use `done <id>` to complete and `remove <id>` to delete — ids come from `list`." }
                }

                HelpTopic {
                    glyph: "\uf240"
                    title: "Battery alerts"
                    summary: "low / critical warnings · history graph"

                    HelpLine { text: "Low battery warns at 18%, critical at 5% — each fires once per discharge and re-arms when you plug in." }
                    HelpLine { text: "Crossing a threshold plays a chime once per discharge and the pill blares orange/red until plugged in — no popup spam." }
                    HelpLine { text: "Left-click the bar pill for details, history graph and power profiles; right-click toggles the percentage inside the pill." }
                    HelpLine { text: "The chart icon in the popup enables a one-hour charge-history graph." }
                }

                HelpTopic {
                    glyph: "\uf0e4"
                    title: "Speed test"
                    summary: "own tab · live progress · last-10 history"

                    HelpLine { text: "It lives in its own Settings → Speedtest tab: latency (best of 3 probes), a 50 MB download and a 9 MB upload against Cloudflare, using curl — no extra packages." }
                    HelpLine { text: "The three bars under the tiles fill with real progress as each probe/chunk lands; the caption shows phase and percentage. A watchdog kills stalled runs, so a test can never hang forever." }
                    HelpLine { text: "Every completed run is saved with the network it ran on (Wi-Fi SSID or Ethernet). The History card keeps the last 10 — the trash icon clears them. Results persist across reloads in speedtest-history.json." }
                }

                HelpTopic {
                    glyph: "\uf133"
                    title: "Calendar & timer"
                    summary: "full-year grid · deep links · countdown presets"

                    HelpLine { text: "Right-click the calendar title flips between month and full-year grids; left-click reveals view tabs (calendar / reminders / timer)." }
                    HelpLine { text: "Deep links jump straight into a view:" }
                    HelpCode { cmd: "qs -p ~/.config/quickshell ipc call calendar year" }
                    HelpCode { cmd: "qs -p ~/.config/quickshell ipc call timer start 300" }
                    HelpLine { text: "The timer offers preset chips (5m–1h) and starts from zero — scroll the spinner to arm a duration, Reset zeroes everything." }
                    HelpLine { text: "Reminder dots on day cells show pending counts; the compose time always opens at the bar clock's current time." }
                }

                HelpTopic {
                    glyph: "\uf144"
                    title: "Media & player chooser"
                    summary: "pin players · wheel cycling · chip mute"

                    HelpLine { text: "With more than one player running, hover the bottom-left of the Now Playing card in quicksettings — a faint ⋯ button appears. Click it to open the player strip." }
                    HelpLine { text: "Scroll the strip to cycle players, click a chip to pin that player, right-click any chip to mute/unmute it. Right- or middle-click anywhere on the card mutes the active player." }
                    HelpLine { text: "The strip auto-closes after ~1 s when the pointer leaves. It can be turned off in Settings → Media → Now Playing." }
                }

                HelpTopic {
                    glyph: "\uf080"
                    title: "Workspaces"
                    summary: "app icons · focus glow · urgent pulse"

                    HelpLine { text: "Settings → Bar → Icon workspaces switches between app icons and numbers. Clicking a pill jumps to that workspace." }
                    HelpLine { text: "Icon pills show every open app; the focused window's icon glows purple while its siblings stay dim. Duplicate windows of one app show a count badge." }
                    HelpLine { text: "A workspace with an urgent window (new message etc.) pulses red until visited." }
                }

                HelpTopic {
                    glyph: "\uf2f2"
                    title: "Power timers"
                    summary: "armed reboot / shutdown countdowns"

                    HelpLine { text: "In quicksettings' power menu, right-click Reboot or Shutdown to open the timer card, then set a delay with the slider (5–240 min)." }
                    HelpLine { text: "A live countdown pill appears in the bar once armed — left-click it to cancel. Arming also works from the timer card's own toggle." }
                }

                HelpTopic {
                    glyph: "\uf1eb"
                    title: "Network"
                    summary: "wifi / ethernet toggles · traffic graphs"

                    HelpLine { text: "In Settings → Connections, click the Wi-Fi tile to toggle the radio and the Ethernet tile to connect/disconnect — border colors track connection state." }
                    HelpLine { text: "Plugging in Ethernet automatically drops Wi-Fi once so traffic takes the faster link — reconnecting manually afterwards is respected." }
                    HelpLine { text: "Both popups support live traffic graphs (chart-icon in the header) and session totals; right-click the bar module toggles the rate readout on the bar itself." }
                }

                HelpTopic {
                    glyph: "\uf0eb"
                    title: "Tips & storage"
                    summary: "shortcuts · where settings live"

                    HelpLine { text: "Escape closes any popup; most tray icons open menus on left-click." }
                    HelpLine { text: "Everything you toggle here persists in ~/.config/quickshell/prefs.json and survives reloads." }
                    HelpLine { text: "Reminders live next to it in reminders.json; both files are plain JSON you can edit." }
                }
            }
        }
    }
}
