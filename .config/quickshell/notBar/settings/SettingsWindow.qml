import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.customItems
import qs.services

Item {
    id: root

    property int currentCategory: 0

    readonly property var categories: [
        { icon: "", label: "General" },
        { icon: "", label: "Bar" },
    ]

    readonly property string hostName: {
        var raw = hostFile.text().trim();
        return raw.length > 0 ? raw : "unknown";
    }

    FileView {
        id: hostFile
        path: "file:///proc/sys/kernel/hostname"
    }

    property string avatarPath: {
        var home = Quickshell.environment.HOME || "/home/" + root.hostName;
        var p = home + "/.config/quickshell/assets/avatar.png";
        return p;
    }

    property string activeInterface: ""
    property string ipAddr: ""
    readonly property string netState: {
        var raw = netFile.text().trim();
        return raw.length > 0 ? raw : "down";
    }
    readonly property bool isOnline: root.netState === "up"

    FileView {
        id: netFile
        path: `file:///sys/class/net/${root.activeInterface}/operstate`
    }

    Process {
        id: interfaceCheck
        running: false
        command: ["sh", "-c", "ip -o route show default 2>/dev/null | head -1 | awk '{print $5}'"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0) {
                    root.activeInterface = data.trim();
                    ipProcess.running = true;
                }
            }
        }
    }

    Process {
        id: ipProcess
        running: false
        command: ["sh", "-c", `ip -4 -o addr show ${root.activeInterface} 2>/dev/null | awk '{print $4}' | head -1`]
        stdout: SplitParser {
            onRead: data => root.ipAddr = data
        }
    }

    Process {
        id: avatarPickProcess
        running: false
        command: ["sh", "-c", `PATH="$HOME/.nix-profile/bin:$PATH" zenity --file-selection --title="Choose Avatar" --file-filter="Images | *.png *.jpg *.jpeg *.webp" 2>/dev/null | while read file; do mkdir -p ~/.config/quickshell/assets && cp "$file" ~/.config/quickshell/assets/avatar.png; done`]
    }

    FileView {
        id: avatarFileWatch
        path: "file://" + root.avatarPath
        onTextChanged: {
            avatarImg.source = "";
            avatarImg.source = "file://" + root.avatarPath;
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
                implicitWidth: 720
                implicitHeight: 480

                anchors.centerIn: parent

                radius: 16
                color: "#1e1e2e"
                border.color: "#45475a"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {} // consume clicks to prevent closing
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 1
                    spacing: 0

                    Rectangle {
                        Layout.preferredWidth: 200
                        Layout.fillHeight: true
                        radius: 16
                        color: "#181825"

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
                                color: "#cdd6f4"
                                font {
                                    pixelSize: 16
                                    bold: true
                                    family: "Quicksand"
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8
                                implicitHeight: 60
                                radius: 8
                                color: Qt.rgba(0.54, 0.57, 0.96, 0.06)
                                Layout.bottomMargin: 12

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    Rectangle {
                                        implicitWidth: 44
                                        implicitHeight: 44
                                        radius: 22
                                        color: "#313244"

                                        Image {
                                            id: avatarImg
                                            anchors.fill: parent
                                            source: "file://" + root.avatarPath
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            color: "#585b70"
                                            font { pixelSize: 20; family: "Symbols Nerd Font Mono" }
                                            visible: avatarImg.status !== Image.Ready
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: avatarPickProcess.running = true
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true

                                        Text {
                                            text: root.hostName
                                            color: "#cdd6f4"
                                            font { pixelSize: 12; family: "Quicksand"; bold: true }
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: root.ipAddr.length > 0
                                                ? root.ipAddr
                                                : (root.isOnline ? "Connected" : "Offline")
                                            color: root.isOnline ? "#a6e3a1" : "#f38ba8"
                                            font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: avatarPickProcess.running = true
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
                                            color: root.currentCategory === index ? "#89b4fa" : "#585b70"
                                            font {
                                                pixelSize: 14
                                                family: "Symbols Nerd Font Mono"
                                            }
                                        }

                                        Text {
                                            text: modelData.label
                                            color: root.currentCategory === index ? "#cdd6f4" : "#a6adc8"
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
                                color: "#313244"
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
                                        color: "#f38ba8"
                                        font {
                                            pixelSize: 14
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    Text {
                                        text: "Close"
                                        color: "#f38ba8"
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

                            Loader {
                                anchors.fill: parent
                                sourceComponent: root.currentCategory === 0 ? generalPage : barPage
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: generalPage

            ColumnLayout {
                spacing: 16

                Text {
                    text: "General"
                    color: "#cdd6f4"
                    font {
                        pixelSize: 20
                        bold: true
                        family: "Quicksand"
                    }
                }

                Text {
                    text: "General system preferences and information."
                    color: "#a6adc8"
                    font {
                        pixelSize: 11
                        family: "ZedMono Nerd Font"
                    }
                    Layout.bottomMargin: 8
                }

                Card {
                    title: "System"
                    icon: ""
                    accent: "#89b4fa"

                    ColumnLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        Text {
                            text: "Hostname"
                            color: "#585b70"
                            font { pixelSize: 9; family: "ZedMono Nerd Font"; bold: true }
                        }
                        Text {
                            text: root.hostName
                            color: "#cdd6f4"
                            font { pixelSize: 13; family: "Quicksand" }
                        }
                    }
                }
            }
        }

        Component {
            id: barPage

            ColumnLayout {
                spacing: 16

                Text {
                    text: "Bar"
                    color: "#cdd6f4"
                    font {
                        pixelSize: 20
                        bold: true
                        family: "Quicksand"
                    }
                }

                Text {
                    text: "Customize the appearance and behavior of the top bar."
                    color: "#a6adc8"
                    font {
                        pixelSize: 11
                        family: "ZedMono Nerd Font"
                    }
                    Layout.bottomMargin: 8
                }

                Card {
                    title: "Style"
                    icon: ""
                    accent: "#89b4fa"

                    ColumnLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: 10
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Text {
                                    text: "Bar Style"
                                    color: "#cdd6f4"
                                    font { pixelSize: 12; family: "Quicksand"; bold: true }
                                }

                                Text {
                                    text: BarState.modernBarStyle ? "Rounded · 28px" : "Flat · 24px"
                                    color: "#585b70"
                                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                }
                            }

                            Rectangle {
                                implicitWidth: 44
                                implicitHeight: 24
                                radius: 12
                                color: BarState.modernBarStyle ? "#89b4fa" : "#45475a"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: "#1e1e2e"
                                    x: BarState.modernBarStyle ? parent.width - width - 3 : 3
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
                    }
                }
            }
        }
    }
}
