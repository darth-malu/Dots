import QtQuick
import QtQuick.Layouts
import qs.services
import qs.customItems
import Quickshell
import qs.themes

RowLayout {
    id: batteryBlock
    spacing: 6
    visible: BatteryState.available

    MouseArea {
        id: root

        readonly property bool isCharging: BatteryState.isCharging
        readonly property bool isLow: BatteryState.isLow
        readonly property bool isPluggedIn: BatteryState.isPluggedIn
        readonly property bool isPendingCharge: BatteryState.isPendingCharge
        readonly property bool isPendingDischarge: BatteryState.isPendingDischarge
        readonly property real percentage: BatteryState.batPercentage
        readonly property bool isFull: BatteryState.isFullyCharged

        property bool togglePerformanceMode: false
        property string currentPerfProfile
        property var powerProfile: BatteryState.powerProfile
        property bool balancedMode: BatteryState.balMode
        property bool performanceMode: BatteryState.perfMode
        property bool powerSaverMode: BatteryState.saverMode

        implicitWidth: batteryBody.width
        implicitHeight: batteryBody.height

        onClicked: mouse => {
            mouse.accepted = true;
            if (mouse.button == Qt.LeftButton)
                togglePerformanceMode = !togglePerformanceMode;
        }

        Rectangle {
            id: batteryBody
            width: 26
            height: 14
            radius: 3
            color: "#313244"
            border.color: "#585b70"
            border.width: 1

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
                color: root.isCharging ? "#a6e3a1" : root.isLow ? "#f38ba8" : Themes.mprisTextColor

                Behavior on width {
                    NumberAnimation { duration: 150 }
                }
            }

            Item {
                anchors.fill: parent

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        id: boltIcon
                        Layout.leftMargin: 1
                        Layout.rightMargin: -3
                        text: "⚡"
                        iconSize: 9
                        visible: root.isCharging
                    }

                    MaterialSymbol {
                        id: plugIcon
                        Layout.leftMargin: 1
                        Layout.rightMargin: -2
                        text: "🔌"
                        iconSize: 8
                        visible: root.isPendingCharge
                    }

                    StyledText {
                        font {
                            pixelSize: 11
                            family: "VictorMono Nerd Font"
                            weight: Font.Bold
                        }
                        text: root.isFull ? '⚡' : Math.round(root.percentage * 100)
                    }
                }
            }
        }

        Rectangle {
            id: cap
            implicitHeight: 6
            implicitWidth: 2
            color: batteryFill.color
            topRightRadius: 999
            bottomRightRadius: 999
            anchors {
                verticalCenter: parent.verticalCenter
                left: batteryBody.right
                leftMargin: 1
            }
        }
    }

    BarBlock {
        id: perfomanceBlock
        visible: root.togglePerformanceMode
        hoveredBg: true
        content: BarText {
            id: perfs
            paddingg: 0
            text: {
                if (root.balancedMode)
                    return '☯';
                if (root.performanceMode)
                    return '⚡';
                if (root.powerSaverMode)
                    return '🍀';
            }
        }
        onClicked: {
            const profiles = ['power-saver', 'performance', 'balanced'];
            let currentIndex = profiles.indexOf(root.powerProfile);
            let nextIndex = (currentIndex + 1) % profiles.length;
            let nextProfile = profiles[nextIndex];

            const icons = {
                'power-saver': '🍀',
                'performance': '⚡',
                'balanced': '☯'
            };
            Quickshell.execDetached(["sh", "-c",
                `powerprofilesctl set ${nextProfile} && notify-send "Power Profile" "${icons[nextProfile]} ${nextProfile}" -u low -a Shell`
            ]);

            root.powerProfile = nextProfile;
        }
    }
}
