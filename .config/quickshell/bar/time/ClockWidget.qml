import qs.themes
import QtQuick
import QtQuick.Layouts
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

    content: Item {
        implicitWidth: timeRow.implicitWidth
        implicitHeight: timeRow.implicitHeight

        RowLayout {
            id: timeRow

            anchors.centerIn: parent
            spacing: 7

            BarText {
                id: timeItself
                symbolText: root.time
                paddingg: 0
                bottomPadding: 2
                font: Themes.monofur
                baseColor: Themes.clockColor
            }

            // noctalia-style bar surface: hourglass while armed, live
            // countdown next to the clock; click jumps into the timer panel
            Item {
                visible: TimerState.active || TimerState.phase === 3
                implicitWidth: timerTxt.implicitWidth
                implicitHeight: timerTxt.implicitHeight

                Text {
                    id: timerTxt

                    anchors.centerIn: parent
                    text: "\uf252 " + TimerState.formatTime(TimerState.remainingSec)
                    // mirrors the panel's urgency palette
                    color: !TimerState.active ? "#50fa7b"
                        : TimerState.phase === 2 ? "#ffb86c"
                        : TimerState.remainingSec <= 60 ? "#ff5555"
                        : TimerState.remainingSec <= 300 ? "#f1fa8c" : Themes.accent
                    font { pixelSize: 11; family: "ZedMono Nerd Font" }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    // noctalia behaviour: a finished countdown resets from the bar,
                    // otherwise the click toggles the timer panel — already
                    // showing it → dismiss, any other view → jump to timer
                    onClicked: mouse => {
                        if (mouse.button !== Qt.LeftButton)
                            return;
                        if (TimerState.phase === 3) {
                            TimerState.reset();
                            return;
                        }
                        if (lazyClock.item && lazyClock.item.isView("timer")) {
                            MiscState.showPopup = false;
                            return;
                        }
                        if (lazyClock.item)
                            lazyClock.item.setView("timer");
                        else
                            root.pendingTarget = "timer";
                        MiscState.showPopup = true;
                    }
                }
            }
        }
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

    // view a deep link should land on when the popup next loads
    // ("year" | "timer" | ""); consumed by the popup on creation
    property string pendingTarget: ""

    IpcHandler {
        target: "calendar"
        function toggle(): void {
            MiscState.showPopup = !MiscState.showPopup;
        }
        function year(): string {
            // jump straight into the full-year grid
            if (lazyClock.item) {
                lazyClock.item.setYearView(true);
                lazyClock.item.dbgSoon();
                return "year → settling";
            }
            root.pendingTarget = "year";
            MiscState.showPopup = true;
            return "popup opening into year view";
        }
        function compact(): string {
            // drop back to the single-month view
            if (lazyClock.item) {
                lazyClock.item.setYearView(false);
                lazyClock.item.dbgSoon();
                return "compact → settling";
            }
            return "popup not open";
        }
        function probe(): string {
            return lazyClock.item ? lazyClock.item.probe() : "not loaded";
        }
        function rem(): string {
            // jump straight into the reminders panel
            if (lazyClock.item) {
                lazyClock.item.setView("rem");
                return "reminders";
            }
            root.pendingTarget = "rem";
            MiscState.showPopup = true;
            return "popup opening into reminders";
        }
        function timer(): string {
            // jump straight into the countdown panel; already there → close
            if (lazyClock.item && lazyClock.item.isView("timer")) {
                MiscState.showPopup = false;
                return "closed";
            }
            if (lazyClock.item) {
                lazyClock.item.setView("timer");
                return TimerState.statusJson();
            }
            root.pendingTarget = "timer";
            MiscState.showPopup = true;
            return TimerState.statusJson();
        }
        function state(): string {
            return lazyClock.item ? lazyClock.item.fullDbg() : "not loaded";
        }
    }

    // loaded fresh per open — a persistent hidden popup window maps with
    // its LAST frame on reopen (blank/half-drawn until a click forces a
    // repaint); rebuilding the window for every open makes the first
    // frame always current, and state resets are inherent to creation.
    // (Quickshell's LazyLoader never unloads on loading:false — the plain
    // Loader actually destroys the tree.)
    Loader {
        id: lazyClock

        active: MiscState.showPopup
        sourceComponent: popupComp
    }

    Component {
        id: popupComp

        PopupWindow {
            id: popup

            // live geometry readout for the calendar IPC debug handler
            readonly property string dbg: `visible=${MiscState.showPopup} view=${clockPopup.view} yearView=${clockPopup.yearView} iw=${implicitWidth} w=${width} ih=${implicitHeight} h=${height} ciw=${clockPopup.implicitWidth} cih=${clockPopup.implicitHeight}`

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

            // size follows the content exactly — NO Behavior here: an
            // animated implicit size makes the window commit intermediate
            // geometries while mapping, which is what showed a blank /
            // half-drawn first frame on open. Atomic resize + the pinned
            // content width below give a complete first frame.
            implicitWidth: clockPopup.width + 28
            implicitHeight: clockPopup.implicitHeight + 28

            // IPC entry points — ids inside the LazyLoader aren't visible
            // outside it; lazyClock.item IS this window, so anything the
            // handlers need must be wrapped here (calling clockPopup's
            // methods directly throws a silent TypeError)
            Timer {
                id: dbgTimer
                interval: 150
                onTriggered: console.log("[caldbg]", dbg)
            }

            function setYearView(on: bool): void {
                clockPopup.yearView = on;
                clockPopup.view = "cal";
            }

            // layout runs a frame after a view flip — immediate reads lie
            function dbgSoon(): void {
                Qt.callLater(() => Qt.callLater(() => dbgTimer.restart()));
            }

            function probe(): string {
                let out = "";
                const ks = clockPopup.children;
                for (let i = 0; i < ks.length; i++) {
                    const c = ks[i];
                    out += `[${i}]v=${c.visible} h=${Math.round(c.height)} ih=${Math.round(c.implicitHeight)} `;
                }
                return `${dbg} ||| ${out}`;
            }

            function setView(v: string): void {
                if (v === "timer")
                    clockPopup.yearView = false;
                clockPopup.switchView(v);
            }

            function isView(v: string): bool {
                return clockPopup.view === v;
            }

            // a deep link queued while the popup was unloaded lands here —
            // anything else opens pristine on the current month.
            // NEVER let the first layout pass happen in year mode: a wide
            // initial pass poisons the ColumnLayout's cached implicit height
            // and it never re-polishes back to compact. Land compact, then
            // flip to the requested view once the frame has settled
            Component.onCompleted: {
                const t = root.pendingTarget;
                if (t === "year")
                    Qt.callLater(() => Qt.callLater(() => setYearView(true)));
                else if (t.length > 0)
                    setView(t);
                root.pendingTarget = "";
            }

            function fullDbg(): string {
                let dump = "children:";
                const ks = clockPopup.children;
                for (let i = 0; i < ks.length; i++) {
                    const c = ks[i];
                    dump += ` [${i}]${c.objectName || c.toString().slice(0, 20)} vis=${c.visible} h=${Math.round(c.height)} ih=${Math.round(c.implicitHeight)} ph=${c.Layout ? Math.round(c.Layout.preferredHeight) : "-"} mh=${c.Layout ? Math.round(c.Layout.maximumHeight) : "-"}`;
                }
                return dbg + "  ||  " + clockPopup.gridDbg + "  ||  " + dump;
            }

            Rectangle {
                id: card

                focus: true
                radius: 12
                anchors.fill: parent
                border.width: 1
                border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.3)
                color: Themes.popupCardBg

                Keys.onEscapePressed: {
                    if (clockPopup.datePickerOpen)
                        clockPopup.datePickerOpen = false;
                    else if (clockPopup.view !== "cal")
                        clockPopup.switchView("cal");
                    else if (clockPopup.yearView)
                        clockPopup.yearView = false;
                    else if (clockPopup.selectedYear >= 0)
                        clockPopup.clearSelection();
                    else if (clockPopup.tabsRevealed)
                        clockPopup.tabsRevealed = false;
                    else
                        MiscState.showPopup = false;
                }

                ClockPopup {
                    id: clockPopup

                    // width is pinned inside ClockPopup (baseWidth) — the
                    // window derives its own size from it. Centered with x
                    // instead of left/right anchors, which would override
                    // the explicit width and resurrect the old
                    // half-laid-out-on-open geometry race.
                    x: Math.round((parent.width - width) / 2)
                    y: 14
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
