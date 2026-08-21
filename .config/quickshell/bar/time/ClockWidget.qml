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
    // color: 'red'

    // anchors.verticalCenter: parent.verticalCenter

    // hoverEnabled: true
    SoundEffect {
        id: beep
        source: Qt.resolvedUrl("../../customItems/game_ready.wav")
    }

    onClicked: mouse => {
        // mouse.accepted = true;
        if (mouse.button === Qt.LeftButton) {
            ResourcesState.resourcesVisible = !ResourcesState.resourcesVisible;
            // beep.play();
        } else if ((mouse.modifiers & Qt.ShiftModifier) && (mouse.button === Qt.RightButton))
            beep.play();
        else if (mouse.button === Qt.RightButton)
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
            grabFocus: true
            color: MiscState.popupSolidBg ? "#282a36" : "transparent"

            anchor.window: root.host
            anchor.rect.x: {
                let globalPos = root.mapToGlobal(0, 0);
                return globalPos.x + (root.width / 2) - (width / 2);
            }

            anchor.rect.y: 33

            implicitWidth: 280
            implicitHeight: clockPopup.inputVisible ? 268 : 220
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                radius: 10
                anchors.fill: parent
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.35)
                color: "#282a36"

                Shortcut {
                    sequence: "Escape"
                    onActivated: {
                        if (clockPopup.inputVisible)
                            clockPopup.clearSelection();
                        else
                            MiscState.showPopup = false;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: MiscState.showPopup = false
                }

                ClockPopup {
                    id: clockPopup
                    anchors.fill: parent
                    anchors.margins: 8
                    onTaskSubmitted: (day, month, year, task) => {
                        MiscState.showPopup = false;
                        MiscState.toggleTrackedDate(year, month, day);

                        var m = (month + 1) < 10 ? '0' + (month + 1) : '' + (month + 1);
                        var d = day < 10 ? '0' + day : '' + day;
                        var key = year + '-' + m + '-' + d;
                        var days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                        var dt = new Date(year, month - 1, day);
                        var dayName = days[dt.getDay()];
                        var initial = "* TODO " + task + "\n  SCHEDULED: <" + key + " " + dayName + ">";
                        Quickshell.execDetached(['emacsclient', '-c', '-n', '-e', '(progn (setq org-capture-initial "' + initial + '") (org-capture nil "t"))']);
                    }
                }
            }
        }
    }
}
