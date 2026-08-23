import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.customItems
import qs.services
import qs.bar.quicksettings.nowplaying
import Quickshell.Services.Mpris
import Quickshell.Networking

Item {
    id: root

    property int currentCategory: 0

    // small shared toggle switch used by the connections page
    component TogglePill: Rectangle {
        id: pill

        property bool on: false
        signal toggled()

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 26
        implicitHeight: 14
        radius: 7
        color: on ? Qt.rgba(189 / 255, 147 / 255, 249 / 255, 0.35) : "#343746"

        Rectangle {
            x: pill.on ? parent.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 10
            implicitHeight: 10
            radius: 5
            color: pill.on ? "#bd93f9" : "#6272a4"

            Behavior on x {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.toggled()
        }
    }

    readonly property var categories: [
        { icon: "\uf080", label: "Bar" },
        { icon: "\uf144", label: "Media" },
        { icon: "\uf1eb", label: "Connections" },
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
                border.color: "#44475a"

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

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: 12
                                Layout.rightMargin: 12
                                height: 1
                                color: "#343746"
                                Layout.bottomMargin: 8
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: 12
                                Layout.rightMargin: 12
                                implicitHeight: 36
                                radius: 8
                                color: "transparent"

                                RowLayout {
                                    anchors {
                                        left: parent.left
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 12
                                    }
                                    spacing: 10

                                    Text {
                                        text: ""
                                        color: "#ff5555"
                                        font {
                                            pixelSize: 14
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    Text {
                                        text: "Close"
                                        color: "#ff5555"
                                        font {
                                            pixelSize: 12
                                            family: "Quicksand"
                                            bold: true
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: MiscState.toggleSettings = false
                                }
                            }
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
                                contentHeight: pageLoader.implicitHeight + 16
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

                                Loader {
                                    id: pageLoader
                                    width: parent.width
                                    sourceComponent: root.currentCategory === 0 ? barPage
                                        : root.currentCategory === 1 ? mediaPage
                                        : connectionsPage
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Media page — mpris pill behaviour + marquee toggle ──
        Component {
            id: mediaPage

            ColumnLayout {
                spacing: 16

                RowLayout {
                    spacing: 10

                    Text {
                        text: "\uf144"
                        color: "#bd93f9"
                        font { pixelSize: 20; family: "Symbols Nerd Font Mono" }
                    }

                    Text {
                        text: "Media"
                        color: "#f8f8f2"
                        font {
                            pixelSize: 20
                            bold: true
                            family: "Quicksand"
                        }
                    }
                }

                Text {
                    text: "Media player pill, popups and title scrolling."
                    color: "#b8bfcb"
                    font { pixelSize: 11; family: "ZedMono Nerd Font" }
                    Layout.bottomMargin: 8
                }

                Card {
                    title: "MPRIS"
                    icon: ""
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            Text {
                                text: "\uf03e"
                                color: "#bd93f9"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    text: "Album art"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: MprisState.mprisArtVisible ? "Cover art shown on pill & popup" : "Art hidden everywhere"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36
                                implicitHeight: 20
                                radius: 10
                                color: MprisState.mprisArtVisible ? "#bd93f9" : "#44475a"
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
                                    x: MprisState.mprisArtVisible ? parent.width - width - 2 : 2
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
                                    onClicked: MprisState.mprisArtVisible = !MprisState.mprisArtVisible
                                }
                            }
                        }

                        // Separator
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#343746"
                            Layout.leftMargin: 28
                        }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            Text {
                                text: "\ue01c"
                                color: "#bd93f9"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    text: "Progress Ring"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: "Visible on pill"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36
                                implicitHeight: 20
                                radius: 10
                                color: MprisState.showMprisProgress ? "#bd93f9" : "#44475a"
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
                                    x: MprisState.showMprisProgress ? parent.width - width - 2 : 2
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
                                    onClicked: MprisState.showMprisProgress = !MprisState.showMprisProgress
                                }
                            }
                        }

                        // Separator
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#343746"
                            Layout.leftMargin: 28
                        }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            Text {
                                text: "\ue03c"
                                color: "#bd93f9"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    text: "Hide when idle"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: MprisState.hideWhenIdle ? "Pill hides when paused" : "Always show pill"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36
                                implicitHeight: 20
                                radius: 10
                                color: MprisState.hideWhenIdle ? "#bd93f9" : "#44475a"
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
                                    x: MprisState.hideWhenIdle ? parent.width - width - 2 : 2
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
                                    onClicked: MprisState.hideWhenIdle = !MprisState.hideWhenIdle
                                }
                            }
                        }

                        // Separator
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#343746"
                            Layout.leftMargin: 28
                        }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            Text {
                                text: "\uf07c"
                                color: "#bd93f9"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    text: "Marquee titles"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: MprisState.marqueeEnabled ? "Long titles scroll" : "Long titles truncate"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36
                                implicitHeight: 20
                                radius: 10
                                color: MprisState.marqueeEnabled ? "#bd93f9" : "#44475a"
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
                                    x: MprisState.marqueeEnabled ? parent.width - width - 2 : 2
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
                                    onClicked: MprisState.marqueeEnabled = !MprisState.marqueeEnabled
                                }
                            }
                        }
                    }
                }

                Text {
                    text: "Now Playing"
                    color: "#f8f8f2"
                    font {
                        pixelSize: 20
                        bold: true
                        family: "Quicksand"
                    }
                }

                Text {
                    text: "Configure now playing controls visibility."
                    color: "#b8bfcb"
                    font {
                        pixelSize: 11
                        family: "ZedMono Nerd Font"
                    }
                    Layout.bottomMargin: 8
                }

                Card {
                    title: "Now Playing"
                    icon: ""
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            Text {
                                text: ""
                                color: MiscState.showShuffle ? "#bd93f9" : "#6272a4"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20; horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Text {
                                    text: "Shuffle"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }
                                Text {
                                    text: "Show shuffle button in controls"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36; implicitHeight: 20; radius: 10
                                color: MiscState.showShuffle ? "#bd93f9" : "#44475a"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: "#282a36"
                                    x: MiscState.showShuffle ? parent.width - width - 2 : 2
                                    y: (parent.height - height) / 2
                                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: MiscState.showShuffle = !MiscState.showShuffle
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 28 }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            Text {
                                text: ""
                                color: MiscState.showLoop ? "#bd93f9" : "#6272a4"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20; horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Text {
                                    text: "Loop"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }
                                Text {
                                    text: "Show loop button in controls"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36; implicitHeight: 20; radius: 10
                                color: MiscState.showLoop ? "#bd93f9" : "#44475a"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: "#282a36"
                                    x: MiscState.showLoop ? parent.width - width - 2 : 2
                                    y: (parent.height - height) / 2
                                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: MiscState.showLoop = !MiscState.showLoop
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 28 }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            Text {
                                text: ""
                                color: MiscState.showPlayerChooser ? "#bd93f9" : "#6272a4"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20; horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Text {
                                    text: "Player Chooser"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }
                                Text {
                                    text: "Show player switcher in now playing"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36; implicitHeight: 20; radius: 10
                                color: MiscState.showPlayerChooser ? "#bd93f9" : "#44475a"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: "#282a36"
                                    x: MiscState.showPlayerChooser ? parent.width - width - 2 : 2
                                    y: (parent.height - height) / 2
                                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: MiscState.showPlayerChooser = !MiscState.showPlayerChooser
                                }
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: connectionsPage

            ColumnLayout {
                spacing: 16

                RowLayout {
                    spacing: 10

                    Text {
                        text: "\uf1eb"
                        color: "#8be9fd"
                        font { pixelSize: 20; family: "Symbols Nerd Font Mono" }
                    }

                    Text {
                        text: "Connections"
                        color: "#f8f8f2"
                        font {
                            pixelSize: 20
                            bold: true
                            family: "Quicksand"
                        }
                    }
                }

                Text {
                    text: "Preferences that live beyond the bar module popups."
                    color: "#b8bfcb"
                    font {
                        pixelSize: 11
                        family: "ZedMono Nerd Font"
                    }
                    Layout.bottomMargin: 8
                }

                Card {
                    title: "Wi-Fi"
                    icon: "\uf1eb"
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        // connected-network design — highlighted green name vs classic dot only
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    text: "Connected highlight"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: MiscState.wifiGreenName ? "connected name tinted green" : "classic white name, dot indicator only"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            TogglePill {
                                on: MiscState.wifiGreenName
                                onToggled: MiscState.wifiGreenName = !MiscState.wifiGreenName
                            }
                        }
                    }
                }

                Card {
                    title: "Ethernet"
                    icon: "\uf796"
                    accent: "#8be9fd"

                    ColumnLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        // session totals — persistent vs graphs-only (old behaviour)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    text: "Session totals"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: MiscState.showNetTotals ? "upload/download totals always visible" : "totals shown only with traffic graphs"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            TogglePill {
                                on: MiscState.showNetTotals
                                onToggled: MiscState.showNetTotals = !MiscState.showNetTotals
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: barPage

            ColumnLayout {
                spacing: 16

                RowLayout {
                    spacing: 10

                    Text {
                        text: "\uf080"
                        color: "#50fa7b"
                        font { pixelSize: 20; family: "Symbols Nerd Font Mono" }
                    }

                    Text {
                        text: "Bar"
                        color: "#f8f8f2"
                        font {
                            pixelSize: 20
                            bold: true
                            family: "Quicksand"
                        }
                    }
                }

                Text {
                    text: "Customize the appearance and behavior of the top bar."
                    color: "#b8bfcb"
                    font {
                        pixelSize: 11
                        family: "ZedMono Nerd Font"
                    }
                    Layout.bottomMargin: 8
                }

                Card {
                    title: "Style"
                    icon: ""
                    accent: "#bd93f9"

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            Text {
                                text: ""
                                color: "#bd93f9"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20; horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    text: "Bar Style"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: BarState.modernBarStyle ? "Rounded · 28px" : "Flat · 24px"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36; implicitHeight: 20; radius: 10
                                color: BarState.modernBarStyle ? "#bd93f9" : "#44475a"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: "#282a36"
                                    x: BarState.modernBarStyle ? parent.width - width - 2 : 2
                                    y: (parent.height - height) / 2

                                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: BarState.modernBarStyle = !BarState.modernBarStyle
                                }
                            }
                        }

                        // Separator
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#343746"; Layout.leftMargin: 28 }

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            Text {
                                text: ""
                                color: "#bd93f9"
                                font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                Layout.preferredWidth: 20; horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    text: "Popup Background"
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: MiscState.popupSolidBg ? "Solid" : "Transparent"
                                    color: "#6272a4"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36; implicitHeight: 20; radius: 10
                                color: MiscState.popupSolidBg ? "#bd93f9" : "#44475a"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: "#282a36"
                                    x: MiscState.popupSolidBg ? parent.width - width - 2 : 2
                                    y: (parent.height - height) / 2

                                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: MiscState.popupSolidBg = !MiscState.popupSolidBg
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
                                { icon: "\uf293", label: "Bluetooth", key: "showBluetooth" },
                                { icon: "\uf1eb", label: "Wi-Fi", key: "showWifi" },
                                { icon: "\uf1e6", label: "Ethernet", key: "showEthernet" },
                                { icon: "\uf240", label: "Battery", key: "showBattery" },
                                { icon: "\uf0a2", label: "Notifications", key: "showNotifTray" }
                            ]

                            delegate: RowLayout {
                                id: modrow

                                required property var modelData

                                spacing: 10
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36

                                Text {
                                    text: modrow.modelData.icon
                                    color: MiscState[modrow.modelData.key] ? "#bd93f9" : "#6272a4"
                                    font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                                    Layout.preferredWidth: 20
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    text: modrow.modelData.label
                                    color: "#f8f8f2"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    readonly property bool on: MiscState[modrow.modelData.key]
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 36; implicitHeight: 20; radius: 10
                                    color: on ? "#bd93f9" : "#44475a"

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Rectangle {
                                        width: 16; height: 16; radius: 8
                                        color: "#282a36"
                                        x: parent.on ? parent.width - width - 2 : 2
                                        y: (parent.height - height) / 2

                                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: MiscState[modrow.modelData.key] = !MiscState[modrow.modelData.key]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
