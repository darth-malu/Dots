import QtQuick
import QtQuick.Layouts
import qs.services
import qs.customItems
import Quickshell
import qs.themes

/* TODO
   + Alternative modes on click eg. time to full, empty, charge rate
 * */

RowLayout {
    id: batteryBlock
    spacing: 6
    visible: BatteryState.available

    MouseArea {
        id: root

        implicitWidth: batteryProgress.implicitWidth

        implicitHeight: batteryProgress.implicitHeight

        readonly property bool isCharging: BatteryState.isCharging

        readonly property int capRadius: 999

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

        onClicked: mouse => {
            mouse.accepted = true;
            if (mouse.button == Qt.LeftButton)
                togglePerformanceMode = !togglePerformanceMode;
        }

        ClippedProgressBar {
            id: batteryProgress
            value: root.percentage
            highlightColor: root.isCharging ? "#a6e3a1" : root.isLow ? "#f38ba8" : Themes.mprisTextColor
            trackColor: "#313244"

            Item {
                width: batteryProgress.valueBarWidth
                height: batteryProgress.valueBarHeight

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
                        font: batteryProgress.font
                        text: root.isFull ? '⚡' : batteryProgress.text
                    }
                }
            }
        }

        Rectangle {
            id: cap
            implicitHeight: 6
            implicitWidth: 2
            color: batteryProgress.highlightColor
            topRightRadius: root.capRadius
            bottomRightRadius: root.capRadius
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.right
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

            Quickshell.execDetached(["sh", "-c", `powerprofilesctl set ${nextProfile} && notify-send -u low -i ${this.content.text} ${nextProfile}`]);

            root.powerProfile = nextProfile;
        }
    }
}
