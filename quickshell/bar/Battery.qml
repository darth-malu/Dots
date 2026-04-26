import QtQuick
import QtQuick.Layouts
import qs.services
import qs.customItems
import Quickshell

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

        readonly property bool isCharging: BatteryState.isCharging // stops at 100 even if still plugged

        readonly property int capRadius: 999

        readonly property bool isLow: BatteryState.isLow

        readonly property bool isPluggedIn: BatteryState.isPluggedIn

        readonly property bool isPendingCharge: BatteryState.isPendingCharge

        readonly property bool isPendingDischarge: BatteryState.isPendingDischarge

        readonly property real percentage: BatteryState.batPercentage // 0.0-1.0 - Energy/Capacity

        readonly property bool isFull: BatteryState.isFullyCharged

        property bool togglePerformanceMode: false

        property string currentPerfProfile

        // hoverEnabled: true

        property var powerProfile: BatteryState.powerProfile

        property bool balancedMode: BatteryState.balMode
        property bool performanceMode: BatteryState.perfMode
        property bool powerSaverMode: BatteryState.saverMode

        // property bool balancedMode: BatteryState.balMode

        onClicked: mouse => {
            mouse.accepted = true;
            if (mouse.button == Qt.LeftButton)
                togglePerformanceMode = !togglePerformanceMode;
        }

        ClippedProgressBar {
            id: batteryProgress
            value: root.percentage
            highlightColor: root.isCharging ? "#7CE577" /*Lime*/ : root.isLow ? "#D295BF" /*pink*/ : Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1)
            trackColor: 'grey'

            Item {
                width: batteryProgress.valueBarWidth
                height: batteryProgress.valueBarHeight

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        id: boltIcon
                        Layout.leftMargin: 1 //can be -ve eg -2
                        Layout.rightMargin: -3
                        // fill: 1
                        text: "⚡"
                        iconSize: 9
                        visible: root.isCharging
                    }

                    MaterialSymbol {
                        id: plugIcon
                        Layout.leftMargin: 1
                        Layout.rightMargin: -2
                        // leftPadding: 3
                        // fill: 1
                        text: "🔌"
                        iconSize: 8
                        visible: root.isPendingCharge
                    }

                    StyledText {
                        // Layout.alignment: Qt.AlignCenter
                        font: batteryProgress.font
                        text: root.isFull ? '⚡' : batteryProgress.text
                    }
                }
            }
        }

        Rectangle {
            id: cap
            implicitHeight: 5
            implicitWidth: 1.5
            color: batteryProgress.highlightColor
            topRightRadius: root.capRadius
            bottomRightRadius: root.capRadius
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.right
                leftMargin: 0.5
            }
        }
    }

    BarBlock {
        id: perfomanceBlock
        visible: root.togglePerformanceMode
        hoveredBg: true
        content: BarText {      // TODO: maybe make a component
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

            // current
            let currentIndex = profiles.indexOf(root.powerProfile);

            //next index - Modulo of current + 1 eg 5/4 0 r 1 so loop back
            let nextIndex = (currentIndex + 1) % profiles.length;
            let nextProfile = profiles[nextIndex];

            Quickshell.execDetached(["sh", "-c", `powerprofilesctl set ${nextProfile} && notify-send -u low -i ${this.content.text} ${nextProfile}`]); // TODO: better Icons here, and menu

            root.powerProfile = nextProfile;
        }
    }
}
