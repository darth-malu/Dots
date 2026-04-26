import qs.themes
import QtMultimedia
import QtQuick
import qs.customItems
import qs.services
import Quickshell.Io
import Quickshell

BarBlock {
    id: root
    required property var host
    readonly property string date: TimeService.date
    readonly property string time: TimeService.time
    readonly property string dateTime: TimeService.dateTime
    hoveredBg: false
    // color: 'red'

    // anchors.verticalCenter: parent.verticalCenter

    // hoverEnabled: true
    SoundEffect {
        id: beep
        source: Qt.resolvedUrl("game_ready.wav")
    }

    onClicked: mouse => {
        // mouse.accepted = true;
        if (mouse.button === Qt.LeftButton) {
            ResourcesState.resourcesVisible = !ResourcesState.resourcesVisible;
            beep.play();
        } else if (mouse.button === Qt.RightButton)
            NetworkState.netspeedVisible = !NetworkState.netspeedVisible;
        else if (mouse.button === Qt.MiddleButton)
            MiscState.showPopup = !MiscState.showPopup;
    }

    content: BarText {
        id: timeItself
        symbolText: root.time
        paddingg: 0
        bottomPadding: 2
        font: Themes.monofur
        baseColor: Themes.clockColor
    }

    IpcHandler {
        target: "Time"

        function currentDate() {
            Quickshell.execDetached(["notify-send", "-i", "office-calendar-symbolic", "Today", root.date]);
        }

        function currentDateTime() {
            Quickshell.execDetached(["notify-send", "-i", "office-calendar-symbolic", "Today", root.dateTime]);
        }
    }

    LazyLoader {
        id: lazyClock
        loading: true

        PopupWindow {
            id: popup
            visible: MiscState.showPopup
            color: 'transparent'
            // closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

            anchor.window: root.host
            // anchor.rect.x: root.host.x - popup.width / 2 // TODO make this bound to clock only
            // anchor.rect.x: root.host.x
            anchor.rect.x: {
                let globalPos = root.mapToGlobal(0, 0);
                // Global X + half clock width - half popup width
                return globalPos.x + (root.width / 2) - (width / 2);
            }

            anchor.rect.y: 33

            implicitWidth: 280
            implicitHeight: 220

            Rectangle {
                radius: 6
                color: Qt.rgba(0.1, 0.04, 0.18, 0.7)
                anchors.fill: parent
                border.width: 1
                border.color: '#A020F0'

                ClockPopup {
                    anchors.fill: parent
                    anchors.margins: 8
                }
            }
        }
    }
}
