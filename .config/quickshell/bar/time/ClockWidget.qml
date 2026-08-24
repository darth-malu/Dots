import qs.themes
import QtQuick
import qs.customItems
import qs.services
import Quickshell.Io
import Quickshell

BarBlock {
    id: root
        onVisibleChanged: if (!visible) MiscState.showPopup = false
    required property var host
    readonly property string date: TimeService.date
    readonly property string time: TimeService.time
    readonly property string dateTime: TimeService.dateTime
    // color: 'red'

    // anchors.verticalCenter: parent.verticalCenter

    // hoverEnabled: true
    function beepPlay() {
        Sfx.playPath("/home/malu/.config/quickshell/customItems/game_ready.wav");
    }

    onClicked: mouse => {
        // mouse.accepted = true;
        if (mouse.button === Qt.LeftButton) {
            ResourcesState.resourcesVisible = !ResourcesState.resourcesVisible;
            // beep.play();
        } else if ((mouse.modifiers & Qt.ShiftModifier) && (mouse.button === Qt.RightButton))
            root.beepPlay();
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

    IpcHandler {
        target: "calendar"
        function toggle(): void {
            MiscState.showPopup = !MiscState.showPopup;
        }
        function year(): string {
            // jump straight into the full-year grid
            if (!lazyClock.item)
                return "popup not loaded";
            lazyClock.item.setYearView(true);
            MiscState.showPopup = true;
            return lazyClock.item.dbg;
        }
        function state(): string {
            return lazyClock.item ? lazyClock.item.fullDbg() : "not loaded";
        }
    }

    LazyLoader {
        id: lazyClock
        loading: true

        PopupWindow {
            id: popup

            // live geometry readout for the calendar IPC debug handler
            readonly property string dbg: `visible=${MiscState.showPopup} yearView=${clockPopup.yearView} iw=${implicitWidth} w=${width} ih=${implicitHeight} h=${height} ciw=${clockPopup.implicitWidth} cih=${clockPopup.implicitHeight}`

            visible: MiscState.showPopup
            grabFocus: true
            color: "transparent"

            anchor.window: root.host
            anchor.rect.x: {
                let globalPos = root.mapToGlobal(0, 0);
                const cx = globalPos.x + (root.width / 2) - (width / 2);
                // clamp inside the monitor — an offscreen-overflowing anchor makes
                // Hyprland refuse to map the popup entirely (blank year view)
                const scrW = root.host?.screen?.width ?? 1920;
                return Math.max(6, Math.min(cx, scrW - width - 6));
            }

            anchor.rect.y: 33

            // widen for the full-year grid so the 12 mini months get room to breathe
            // (content implicitWidth + 2×14 popup margins, matching Battery/Mpris cards)
            implicitWidth: clockPopup.yearView ? 592 : 292
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
            // size to actual content so the year view fits its grid without dead space
            implicitHeight: clockPopup.implicitHeight + 28
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            // IPC entry point — ids inside the LazyLoader aren't visible outside it
            function setYearView(on: bool): void {
                clockPopup.yearView = on;
            }

            function fullDbg(): string {
                return dbg + "  ||  " + clockPopup.gridDbg;
            }

            Rectangle {
                radius: 12
                anchors.fill: parent
                border.width: 1
                border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)
                color: MiscState.popupCardBg

                Shortcut {
                    sequence: "Escape"
                    onActivated: {
                        if (clockPopup.yearView)
                            clockPopup.yearView = false;
                        else if (clockPopup.inputVisible)
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

                    // stretch to the window bounds — ColumnLayout manages its
                    // own implicitWidth, so pinning via width: implicitWidth
                    // collapsed to the children's minimum and left dead space
                    // on the right; height stays implicit so the card grows
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 14
                    }
                    onTaskSubmitted: (day, month, year, task) => {
                        // the reminder itself is already stored by
                        // ReminderState (ClockPopup.submitInput) — this hook
                        // only closes the popup and mirrors the day in the
                        // legacy tracked-date map for org-capture users
                        MiscState.showPopup = false;
                        MiscState.toggleTrackedDate(year, month, day);
                    }
                }

                // (scroll-to-switch-month removed — the wheel now drives
                // the reminder TimeSpinner segments instead)
            }
        }
    }
}
