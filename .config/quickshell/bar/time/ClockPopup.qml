import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.themes
import qs.services
import qs.customItems

ColumnLayout {
    id: root
    spacing: 8

    // compact for calendar/reminders/timer, wide only for the full-year grid.
    // explicit width, never implicitWidth — a layout overwrites its own
    // implicit size at polish time, which is exactly what left the popup
    // half-laid-out on the frame it mapped; a pinned width lays out every
    // fillWidth child correctly on the first rendered frame
    readonly property int baseWidth: view === "cal" && yearView ? 564 : 300
    width: baseWidth

    // IPC debug: live geometry of the year-view columns
    readonly property string gridDbg: {
        const g = yearLoader.item;
        if (!g)
            return "yearGrid hidden";
        let s = `gw=${Math.round(g.width)} | `;
        for (let i = 0; i < g.children.length; i++) {
            const c = g.children[i];
            if (c.index !== undefined)
                s += `[${c.index}]x=${Math.round(c.x)}w=${Math.round(c.width)}pw=${Math.round(c.Layout.preferredWidth)} `;
        }
        return s;
    }

    signal taskSubmitted(int day, int month, int year, string task)

    // ── view switcher ──
    property string view: "cal" // "cal" | "rem" | "timer"

    // id of the reminder currently being edited in the compose card
    // (real, not int — ids are epoch-millis and overflow 32-bit)
    property real editingId: -1

    // the tab header stays out of the way until the month-name area is
    // clicked; any jump into another view re-reveals it so you can't get stuck
    property bool tabsRevealed: false

    // compose-card pieces live inside the deferred reminders component —
    // resolve them through the loader, tolerating a not-yet-built view
    function _spin() {
        return remLoader.item ? remLoader.item.spinner : null;
    }

    function _field() {
        return remLoader.item ? remLoader.item.field : null;
    }

    function switchView(v) {
        if (v !== "cal")
            tabsRevealed = true;
        const wasRem = view === "rem";
        if (v !== "rem") {
            datePickerOpen = false;
            editingId = -1;
        }
        // flip first — entering "rem" must activate the deferred component
        // before its spinner can be touched
        view = v;
        // entering compose fresh → prefill the spinner with the time right
        // now, not whenever quickshell (or the open popup) started
        if (v === "rem" && !wasRem) {
            ensureReminderSel();
            const sp = _spin();
            if (sp)
                sp.reset();
        }
    }

    property int displayMonth: TimeService.currentDate.getMonth()
    property int displayYear: TimeService.currentDate.getFullYear()

    property bool yearView: false

    property int selectedDay: -1
    property int selectedMonth: -1
    property int selectedYear: -1

    // inline mini-month popover opened from the calendar-icon chip
    property bool datePickerOpen: false
    property int pickerMonth: TimeService.currentDate.getMonth()
    property int pickerYear: TimeService.currentDate.getFullYear()

    // YYYY-MM-DD key for the selected day (falls back to today)
    readonly property string selectedKey: effectiveYear < 0 ? "" : effectiveYear + "-" + String(effectiveMonth + 1).padStart(2, "0") + "-" + String(effectiveDay).padStart(2, "0")

    readonly property int effectiveDay: selectedDay >= 0 ? selectedDay : TimeService.currentDate.getDate()
    readonly property int effectiveMonth: selectedMonth >= 0 ? selectedMonth : TimeService.currentDate.getMonth()
    readonly property int effectiveYear: selectedYear >= 0 ? selectedYear : TimeService.currentDate.getFullYear()

    function clearSelection() {
        selectedDay = -1;
        selectedMonth = -1;
        selectedYear = -1;
        datePickerOpen = false;
        editingId = -1;
        const f = _field();
        if (f)
            f.text = "";
        const sp = _spin();
        if (sp)
            sp.reset();
    }

    // load an existing reminder into the compose card — pencil icon on a
    // list row; submit then updates instead of creating
    function startEdit(rem) {
        const p = rem.date.split("-");
        selectedYear = parseInt(p[0]);
        selectedMonth = parseInt(p[1]) - 1;
        selectedDay = parseInt(p[2]);
        editingId = rem.id;
        datePickerOpen = false;
        tabsRevealed = true;
        view = "rem";
        _field().text = rem.text;
        const sp = _spin();
        if (rem.time && rem.time.length === 5)
            sp.setTime(rem.time.substring(0, 2), rem.time.substring(3, 5));
        else
            sp.reset();
        _field().forceActiveFocus();
    }

    // entering the reminders view with no picked day defaults to today
    function ensureReminderSel() {
        if (selectedYear >= 0)
            return;
        const now = TimeService.currentDate;
        selectedDay = now.getDate();
        selectedMonth = now.getMonth();
        selectedYear = now.getFullYear();
    }

    // click a calendar day → compose a reminder for it in the reminders view
    function openReminderFor(day, month, year, fromMini) {
        selectedDay = day;
        selectedMonth = month;
        selectedYear = year;
        if (fromMini) {
            displayMonth = month;
            yearView = false;
        }
        // direct jump from a day cell — keep the tabs reachable
        tabsRevealed = true;
        view = "rem";
        datePickerOpen = false;
        _spin().reset();
        _field().forceActiveFocus();
    }

    // submit the input: updates the reminder being edited, or creates a new
    // one for the chosen day/time
    function submitInput() {
        const f = _field();
        const sp = _spin();
        if (!f || !sp)
            return;
        const t = f.text.trim();
        if (t.length === 0)
            return;
        ensureReminderSel();
        if (editingId >= 0) {
            if (ReminderState.update(editingId, t, root.selectedKey, sp.timeString))
                clearSelection();
            return;
        }
        // spinner defaults to the current time, so every reminder is timed
        ReminderState.add(t, root.selectedKey, sp.timeString);
        root.taskSubmitted(root.effectiveDay, root.effectiveMonth, root.effectiveYear, t);
        root.clearSelection();
    }

    function openPicker() {
        ensureReminderSel();
        pickerMonth = selectedMonth;
        pickerYear = selectedYear;
        datePickerOpen = true;
    }

    function pickerPrev() {
        if (pickerMonth === 0) {
            pickerMonth = 11;
            pickerYear -= 1;
        } else {
            pickerMonth -= 1;
        }
    }

    function pickerNext() {
        if (pickerMonth === 11) {
            pickerMonth = 0;
            pickerYear += 1;
        } else {
            pickerMonth += 1;
        }
    }

    // reminders grouped per day for the popup list ("Today", "Tomorrow", …)
    readonly property var dayGroups: {
        // TimeService ticks every minute and is what the bar clock shows —
        // reading it here keeps "Overdue"/time-window rendering honest AND
        // in sync while the popup sits open past a due time
        const now = TimeService.currentDate;
        const nowTime = Qt.formatDateTime(now, "HH:mm");
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const groups = [];
        let cur = null;
        for (const r of ReminderState.pending.slice(0, 24)) {
            const overdue = r.date + (r.time || "99:99") < ReminderState.todayKey + nowTime;
            let rel;
            const p = r.date.split("-");
            const d = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]));
            const wd = days[d.getDay()];
            if (r.date === ReminderState.todayKey)
                rel = "Today";
            else if (r.date === ReminderState.tomorrowKey)
                rel = "Tomorrow";
            else
                rel = months[d.getMonth()] + " " + d.getDate();
            let header = wd + ", " + rel;
            if (overdue && r.date <= ReminderState.todayKey)
                header = "Overdue · " + header;
            if (!cur || cur.header !== header) {
                cur = {
                    header: header,
                    overdue: overdue,
                    items: []
                };
                groups.push(cur);
            }
            cur.items.push(r);
        }
        for (const g of groups) {
            const ts = g.items.map(x => x.time).filter(Boolean).sort();
            if (ts.length === 1)
                g.header += "  ·  " + ts[0];
            else if (ts.length > 1)
                g.header += "  ·  " + ts[0] + "–" + ts[ts.length - 1];
        }
        return groups;
    }

    function prevMonth() {
        clearSelection();
        if (displayMonth === 0) {
            displayMonth = 11;
            displayYear -= 1;
        } else {
            displayMonth -= 1;
        }
    }

    function nextMonth() {
        clearSelection();
        if (displayMonth === 11) {
            displayMonth = 0;
            displayYear += 1;
        } else {
            displayMonth += 1;
        }
    }

    function shiftYear(dir) {
        clearSelection();
        displayYear += dir;
    }

    // ── view tabs (hidden until the month title is clicked) ──
    Rectangle {
        id: tabPill

        visible: root.tabsRevealed
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: tabsRow.implicitWidth + 6
        implicitHeight: 26
        radius: 13
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        Row {
            id: tabsRow

            anchors.centerIn: parent
            spacing: 2

            component ViewTab: Rectangle {
                id: tab

                property string icon
                property string label
                property bool active: false
                property int badge: 0
                signal activated()

                width: 76
                height: 20
                radius: 10
                color: active ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.22) : tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.icon
                        color: tab.active ? Themes.accent : Themes.mutedSoft
                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.label
                        color: tab.active ? Themes.accentSoft : Themes.mutedSoft
                        font { pixelSize: 9; bold: tab.active; family: "Quicksand"; letterSpacing: 0.5 }
                    }

                    // pending-reminder count chip (bell tab only)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tab.badge > 0
                        implicitWidth: Math.max(badgeTxt.implicitWidth + 6, 12)
                        implicitHeight: 11
                        radius: 5.5
                        color: Themes.accent

                        Text {
                            id: badgeTxt

                            anchors.centerIn: parent
                            text: tab.badge
                            color: Themes.panelBg
                            font { pixelSize: 7; bold: true; family: "ZedMono Nerd Font" }
                        }
                    }
                }

                MouseArea {
                    id: tabMa

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.activated()
                }
            }

            ViewTab {
                icon: "\uf073"
                label: "Calendar"
                active: root.view === "cal"
                onActivated: root.switchView("cal")
            }

            ViewTab {
                icon: "\uf0f3"
                label: "Remind"
                active: root.view === "rem"
                badge: ReminderState.pending.length
                onActivated: root.switchView("rem")
            }

            ViewTab {
                icon: "\uf017"
                label: "Timer"
                active: root.view === "timer"
                onActivated: root.switchView("timer")
            }
        }
    }

    // ════════════════ CALENDAR VIEW ════════════════
    RowLayout {
        visible: root.view === "cal"
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 4

        Text {
            text: "\uf104"
            color: Themes.calendarHeader
            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.yearView ? root.shiftYear(-1) : root.prevMonth()
            }
        }

        Item { Layout.fillWidth: true }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: periodLabel.implicitWidth
            implicitHeight: periodLabel.implicitHeight

            BarText {
                id: periodLabel
                anchors.centerIn: parent
                font: Themes.quicksand
                color: Themes.calendarHeader
                text: root.yearView ? `${root.displayYear}` : Qt.formatDateTime(
                    new Date(root.displayYear, root.displayMonth, 1),
                    "MMMM yyyy"
                )
                pointSize: 13
            }

            // click the title to show/hide the view tabs; right-click still
            // flips between the month grid and the full-year grid
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.clearSelection();
                        root.yearView = !root.yearView;
                        return;
                    }
                    root.tabsRevealed = !root.tabsRevealed;
                }
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "\uf105"
            color: Themes.calendarHeader
            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.yearView ? root.shiftYear(1) : root.nextMonth()
            }
        }
    }

    DayOfWeekRow {
        Layout.preferredHeight: 18
        visible: root.view === "cal" && !root.yearView
        Layout.fillWidth: true
        font: Themes.quicksand
        delegate: Text {
            horizontalAlignment: Text.AlignHCenter
            color: Themes.calendarDayRow
            text: model.shortName
            textFormat: Text.RichText
            renderType: Text.NativeRendering
            font: Themes.quicksand
        }
    }

    MonthGrid {
        id: grid
        visible: root.view === "cal" && !root.yearView
        Layout.fillWidth: true
        // MonthGrid has no useful implicit size — pin it to 6 week rows of ~34px
        Layout.preferredHeight: 204
        month: root.displayMonth
        year: root.displayYear

        delegate: Item {
            id: dayCell

            // cells fill the whole popup width (grid divides evenly) — scale
            // the day circle with the cell so the month spans edge to edge
            readonly property real cellW: width > 0 ? width : 40
            readonly property real cellH: height > 0 ? height : 32
            readonly property real circleSz: Math.min(36, Math.min(cellW, cellH) - 4)

            property bool hovered: false

            readonly property bool isSelected: model.day === root.selectedDay
                && model.month === root.selectedMonth
                && model.year === root.selectedYear

            readonly property bool isToday: model.today

            readonly property int remCount: ReminderState.countForDate(model.year, model.month, model.day)

            Rectangle {
                width: dayCell.circleSz
                height: dayCell.circleSz
                anchors.centerIn: parent
                radius: width / 2
                visible: model.today && !parent.isSelected
                color: Themes.calendarToday
                opacity: 0.85
            }

            Rectangle {
                width: dayCell.circleSz
                height: dayCell.circleSz
                anchors.centerIn: parent
                radius: width / 2
                visible: parent.isSelected
                color: "transparent"
                border.width: 2
                border.color: Themes.calendarToday
            }

            Text {
                anchors.centerIn: parent
                text: model.day
                font: Themes.quicksand
                color: {
                    if (parent.isSelected) return Themes.calendarToday;
                    if (model.today) return Themes.panelBg;
                    if (dayCell.hovered) return Themes.calendarToday;
                    if (model.month === grid.month) return Themes.calendarActiveMonth;
                    return Themes.calendarInactiveMonth;
                }
            }

            // reminder dots — up to three under the number (sole indicator
            // in month view; counts live in the reminders view)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                spacing: 2
                visible: dayCell.remCount > 0

                Repeater {
                    model: Math.min(3, dayCell.remCount)

                    Rectangle {
                        width: 3.5
                        height: 3.5
                        radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: dayCell.isToday || dayCell.isSelected ? Themes.panelBg : Themes.accent
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: dayCell.hovered = true
                onExited: dayCell.hovered = false
                onClicked: root.openReminderFor(model.day, model.month, model.year, false)
            }
        }
    }

    // ── calendar footer — legend left · jump-to-today right (fills the
    // full window width instead of leaving the lower corners empty) ──
    RowLayout {
        visible: root.view === "cal" && !root.yearView
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: 8

        Row {
            spacing: 5

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: 5
                radius: 2.5
                color: Themes.accent
            }

            Text {
                text: "has reminders"
                color: Themes.muted
                font { pixelSize: 9; family: "Quicksand" }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "·  right-click title for year"
                color: Qt.rgba(1, 1, 1, 0.18)
                font { pixelSize: 9; family: "Quicksand" }
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            readonly property bool isCurrentMonth: root.displayMonth === TimeService.currentDate.getMonth()
                && root.displayYear === TimeService.currentDate.getFullYear()

            implicitWidth: todayRow.implicitWidth + 16
            implicitHeight: 22
            radius: 11
            visible: !isCurrentMonth
            color: todayMa.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.07)

            Behavior on color {
                ColorAnimation { duration: 110 }
            }

            Row {
                id: todayRow

                anchors.centerIn: parent
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf073"
                    color: Themes.accent
                    font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "today"
                    color: todayMa.containsMouse ? Themes.accentSoft : Themes.mutedSoft
                    font { pixelSize: 9; bold: true; family: "Quicksand" }
                }
            }

            MouseArea {
                id: todayMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.clearSelection();
                    root.displayMonth = TimeService.currentDate.getMonth();
                    root.displayYear = TimeService.currentDate.getFullYear();
                }
            }
        }
    }

    // ── Full-year view (toggle via the title) ──
    // built on demand — 12 MonthGrids ≈ 500 delegate objects would dominate
    // popup-open time for a view most opens never enter
    Loader {
        id: yearLoader

        active: root.view === "cal" && root.yearView
        // invisible items are skipped by layout sizing — an unloaded Loader
        // keeps its last geometry otherwise and pins the popup tall
        visible: active
        Layout.fillWidth: true
        // an unloaded Loader keeps its last item's size alive inside the
        // layout no matter what the attached hints say — pin the real
        // height instead so toggling back to compact fully retracts
        height: active ? implicitHeight : 0
        Layout.preferredHeight: height

        sourceComponent: GridLayout {
            id: yearGrid

            columns: 3
            columnSpacing: 14
            rowSpacing: 16

        Repeater {
            model: 12

            ColumnLayout {
                id: miniMonth

                required property int index

                // stretch across the cell AND pin an explicit equal width —
                // implicit+fillWidth alone lets GridLayout dump most of the
                // row into the first column (uneven months)
                Layout.fillWidth: true
                Layout.preferredWidth: (yearGrid.width - 2 * yearGrid.columnSpacing) / 3
                Layout.alignment: Qt.AlignTop

                spacing: 3

                Text {
                    text: Qt.formatDateTime(new Date(2000, miniMonth.index, 1), "MMM")
                    color: root.displayMonth === miniMonth.index ? Themes.calendarToday : Themes.calendarHeader
                    font { pixelSize: 12; bold: true; family: "Quicksand"; letterSpacing: 1 }
                    Layout.alignment: Qt.AlignHCenter
                }

                MonthGrid {
                    month: miniMonth.index
                    year: root.displayYear
                    spacing: 0
                    Layout.fillWidth: true
                    // 6 week rows of ~19px — implicit size must be explicit here too
                    Layout.preferredHeight: 116

                    delegate: Item {
                        id: miniDay

                        property bool hovered: false

                        implicitWidth: 18
                        implicitHeight: 19

                        readonly property bool hasRemindersMini: ReminderState.countForDate(model.year, model.month, model.day) > 0

                        // hover / today circle — mirrors the month view aesthetic
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) - 2
                            height: width
                            radius: width / 2
                            visible: miniDay.hovered || model.today
                            color: model.today ? Themes.calendarToday : Themes.calendarToday
                            opacity: model.today ? 0.85 : 0.16
                        }

                        Text {
                            anchors.centerIn: parent
                            text: model.day
                            font { pixelSize: 10; family: "Quicksand" }
                            color: {
                                if (model.today)
                                    return Themes.panelBg;
                                if (miniDay.hovered)
                                    return Themes.calendarToday;
                                return model.month === miniMonth.index ? Themes.calendarActiveMonth : Themes.calendarInactiveMonth;
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 4
                            height: 4
                            radius: 2
                            color: Themes.calendarActiveMonth
                            visible: parent.hasRemindersMini
                        }

                        // click a day to compose a reminder for it
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: miniDay.hovered = true
                            onExited: miniDay.hovered = false
                            onClicked: root.openReminderFor(model.day, model.month, model.year, true)
                        }
                    }
                }
            }
        }
        }
    }

    // ════════════════ REMINDERS VIEW ════════════════
    // ════════════════ REMINDERS VIEW ════════════════
    // deferred like the year grid — compose card + list aren't needed
    // until the reminders tab is actually opened
    Loader {
        id: remLoader

        active: root.view === "rem"
        visible: active
        Layout.fillWidth: true
        Layout.preferredWidth: root.baseWidth
        Layout.maximumWidth: root.baseWidth
        height: active ? implicitHeight : 0
        Layout.preferredHeight: height

        sourceComponent: remViewComp
    }

    Component {
        id: remViewComp

    ColumnLayout {
        // reachable from root scope only through these aliases — ids inside
        // a deferred component aren't resolvable from outside
        property alias spinner: timeSpin
        property alias field: taskField
        // nested layouts refuse to grow past their implicit width even with
        // fillWidth alone — pin the span to the popup content width
        Layout.fillWidth: true
        Layout.preferredWidth: root.baseWidth
        Layout.maximumWidth: root.baseWidth
        spacing: 8

        // ── compose card ──
        Rectangle {
            id: addCard

            Layout.fillWidth: true
            implicitHeight: addCol.implicitHeight + 20
            radius: 10
            color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.16)

            ColumnLayout {
                id: addCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 7

                // row 1: date chip (calendar icon → picker) + time spinner
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // date chip — calendar icon pops up the mini-month picker
                    Rectangle {
                        id: dateChip

                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 10
                        color: chipMa.containsMouse || root.datePickerOpen ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.14) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: root.datePickerOpen ? 1.5 : 1
                        border.color: root.datePickerOpen ? Themes.accent : chipMa.containsMouse ? "#565d78" : "#3b3f54"

                        Behavior on border.color {
                            ColorAnimation { duration: 120 }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uf073"
                                color: Themes.accent
                                font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                                    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                                    var dt = new Date(root.effectiveYear, root.effectiveMonth, root.effectiveDay);
                                    return days[dt.getDay()] + ", " + months[root.effectiveMonth] + " " + root.effectiveDay;
                                }
                                color: Themes.accentSoft
                                font { pixelSize: 10; bold: true; family: "Quicksand" }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.datePickerOpen ? "\uf077" : "\uf078"
                                color: Themes.mutedSoft
                                font { pixelSize: 8; family: "Symbols Nerd Font Mono" }
                            }
                        }

                        MouseArea {
                            id: chipMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.datePickerOpen ? root.datePickerOpen = false : root.openPicker()
                        }
                    }

                    TimeSpinner {
                        id: timeSpin

                        Layout.alignment: Qt.AlignVCenter

                        onDirtyChanged: {
                            if (dirty)
                                taskField.forceActiveFocus();
                        }

                        Keys.onReturnPressed: root.submitInput()
                        Keys.onEnterPressed: root.submitInput()
                        Keys.onEscapePressed: root.clearSelection()
                    }
                }

                // row 2: reminder text + add button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    TextField {
                        id: taskField

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: root.editingId >= 0 ? "editing — enter keeps changes" : "remember to…"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.25)
                        color: Themes.fg
                        font { pixelSize: 11; family: "Quicksand" }
                        background: Rectangle {
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: taskField.activeFocus ? Themes.calendarToday : "#3b3f54"
                            border.width: taskField.activeFocus ? 1.5 : 1
                        }
                        leftPadding: 9
                        rightPadding: 9
                        topPadding: 0
                        bottomPadding: 0
                        verticalAlignment: Text.AlignVCenter
                        selectByMouse: true

                        Keys.onReturnPressed: root.submitInput()
                        Keys.onEnterPressed: root.submitInput()
                        Keys.onEscapePressed: root.clearSelection()
                    }

                    Rectangle {
                        id: addBtn

                        // turns into a green check while a reminder is being edited
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 8
                        color: addMa.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.28) : Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.16)
                        border.width: 1
                        border.color: root.editingId >= 0 ? Qt.rgba(0.31, 0.98, 0.48, 0.45) : Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.35)

                        Behavior on border.color {
                            ColorAnimation { duration: 120 }
                        }

                        scale: addMa.pressed ? 0.92 : 1

                        Behavior on scale {
                            NumberAnimation { duration: 80 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.editingId >= 0 ? "\uf00c" : "\uf067"
                            color: root.editingId >= 0 ? "#50fa7b" : Themes.accent
                            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
                        }

                        MouseArea {
                            id: addMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submitInput()
                        }
                    }
                }

                // ── inline mini-month date picker (calendar-icon popover) ──
                // also deferred — a third 42-cell MonthGrid the compose card
                // doesn't need until the chip is clicked
                Loader {
                    active: root.datePickerOpen
                    visible: active
                    Layout.fillWidth: true
                    height: active ? implicitHeight : 0
                    Layout.preferredHeight: height

                    sourceComponent: Rectangle {
                        id: pickerPanel

                        Layout.fillWidth: true
                        implicitHeight: pickerCol.implicitHeight + 12
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.06)

                    ColumnLayout {
                        id: pickerCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "\uf104"
                                color: Themes.calendarHeader
                                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pickerPrev()
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: Qt.formatDateTime(new Date(root.pickerYear, root.pickerMonth, 1), "MMMM yyyy")
                                color: Themes.calendarHeader
                                font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 0.5 }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "\uf105"
                                color: Themes.calendarHeader
                                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pickerNext()
                                }
                            }
                        }

                        DayOfWeekRow {
                            Layout.fillWidth: true
                            delegate: Text {
                                horizontalAlignment: Text.AlignHCenter
                                color: Themes.calendarInactiveMonth
                                text: model.shortName
                                textFormat: Text.RichText
                                renderType: Text.NativeRendering
                                font { pixelSize: 7; family: "Quicksand" }
                            }
                        }

                        MonthGrid {
                            id: pickGrid

                            Layout.fillWidth: true
                            Layout.preferredHeight: 150
                            month: root.pickerMonth
                            year: root.pickerYear

                            delegate: Item {
                                id: pickCell

                                property bool hovered: false

                                implicitWidth: 24
                                implicitHeight: 25

                                readonly property bool isSelected: model.day === root.selectedDay
                                    && model.month === root.selectedMonth
                                    && model.year === root.selectedYear

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 21
                                    height: 21
                                    radius: width / 2
                                    visible: model.today && !parent.isSelected
                                    color: Themes.calendarToday
                                    opacity: 0.85
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 21
                                    height: 21
                                    radius: width / 2
                                    visible: parent.isSelected || pickCell.hovered
                                    color: parent.isSelected ? "transparent" : Themes.calendarToday
                                    opacity: parent.isSelected ? 1 : 0.16
                                    border.width: parent.isSelected ? 1.5 : 0
                                    border.color: Themes.calendarToday
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: model.day
                                    font { pixelSize: 9; family: "Quicksand" }
                                    color: {
                                        if (pickCell.isSelected)
                                            return Themes.calendarToday;
                                        if (model.today)
                                            return Themes.panelBg;
                                        if (pickCell.hovered)
                                            return Themes.calendarToday;
                                        return model.month === pickGrid.month ? Themes.calendarActiveMonth : Themes.calendarInactiveMonth;
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: pickCell.hovered = true
                                    onExited: pickCell.hovered = false
                                    onClicked: {
                                        root.selectedDay = model.day;
                                        root.selectedMonth = model.month;
                                        root.selectedYear = model.year;
                                        root.displayMonth = model.month;
                                        root.displayYear = model.year;
                                        root.datePickerOpen = false;
                                        taskField.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
                }
            }
        }

        // ── list card: grouped by day ──
        Rectangle {
            id: remCard

            Layout.fillWidth: true
            // cap the list so the popup stays sane with many entries
            implicitHeight: listFlick.visible ? Math.min(listCol.implicitHeight + 58, 420) : emptyTxt.implicitHeight + 44
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.03)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)

            ColumnLayout {
                id: remHeadCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 11
                spacing: 6

                RowLayout {
                    Layout.leftMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 6

                    Text {
                        text: "\uf0f3"
                        color: Themes.accent
                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                    }

                    Text {
                        text: "Upcoming"
                        color: Themes.accent
                        font { pixelSize: 9; bold: true; family: "Quicksand"; letterSpacing: 1 }
                    }

                    Rectangle {
                        implicitWidth: remCount.implicitWidth + 10
                        implicitHeight: 14
                        radius: 7
                        color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.16)

                        Text {
                            id: remCount

                            anchors.centerIn: parent
                            text: ReminderState.pending.length
                            color: Themes.accent
                            font { pixelSize: 8; bold: true; family: "ZedMono Nerd Font" }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "\uf00d"
                        color: clrMa.containsMouse ? "#ff5555" : "#4c5069"
                        font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                        visible: ReminderState.pending.length > 0

                        MouseArea {
                            id: clrMa

                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                for (const r of ReminderState.pending)
                                    ReminderState.remove(r.id);
                            }
                        }
                    }
                }

                Text {
                    id: emptyTxt

                    visible: ReminderState.pending.length === 0
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    text: "nothing pending — enjoy the quiet"
                    color: Themes.muted
                    font { pixelSize: 10; family: "Quicksand"; letterSpacing: 0.5 }
                }

                Flickable {
                    id: listFlick

                    visible: ReminderState.pending.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(listCol.implicitHeight, 330)
                    contentHeight: listCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: listFlick.contentHeight > listFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }

                    ColumnLayout {
                        id: listCol

                        width: listFlick.width
                        spacing: 0

                        Repeater {
                            id: remRep

                            model: root.dayGroups

                            delegate: ColumnLayout {
                                id: remGroup

                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.topMargin: index === 0 ? 0 : 9
                                spacing: 3

                                Text {
                                    Layout.leftMargin: 2
                                    text: remGroup.modelData.header
                                    color: remGroup.modelData.overdue ? "#ff8c8c" : Themes.dim
                                    font { pixelSize: 10; bold: true; family: "Quicksand"; letterSpacing: 0.5 }
                                }

                                Repeater {
                                    model: remGroup.modelData.items

                                    delegate: Rectangle {
                                        id: remRow

                                        required property var modelData

                                        readonly property bool isEdited: root.editingId === modelData.id

                                        Layout.fillWidth: true
                                        implicitHeight: 24
                                        radius: 6
                                        color: isEdited ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.12) : remHover.containsMouse ? Themes.separator : Qt.rgba(1, 1, 1, 0.02)

                                        Behavior on color {
                                            ColorAnimation { duration: 110 }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 9
                                            anchors.rightMargin: 7
                                            spacing: 7

                                            Text {
                                                text: remRow.modelData.time || "--:--"
                                                color: remRow.modelData.overdue ? "#ff8c8c" : Themes.accent
                                                font { pixelSize: 9; bold: true; family: "ZedMono Nerd Font" }
                                                Layout.preferredWidth: 36
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: remRow.modelData.text
                                                color: Themes.fg
                                                font { pixelSize: 10; family: "Quicksand" }
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }

                                            // edit — loads the reminder back into the compose card
                                            Text {
                                                text: "\uf044"
                                                color: remRow.isEdited ? Themes.accent : edtMa.containsMouse ? Themes.accent : "#4c5069"
                                                font { pixelSize: 9; family: "Symbols Nerd Font Mono" }

                                                MouseArea {
                                                    id: edtMa

                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.startEdit(remRow.modelData)
                                                }
                                            }

                                            Text {
                                                text: "\uf00d"
                                                color: delMa.containsMouse ? "#ff5555" : "#4c5069"
                                                font { pixelSize: 10; family: "Symbols Nerd Font Mono" }

                                                MouseArea {
                                                    id: delMa

                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: ReminderState.remove(remRow.modelData.id)
                                                }
                                            }
                                        }

                                        HoverHandler {
                                            id: remHover
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
    }

    // ════════════════ TIMER VIEW ════════════════
    // deferred like the year grid — ring canvas + spinners aren't needed
    // until the timer tab is actually opened
    Loader {
        active: root.view === "timer"
        // same nested-layout quirk: fillWidth alone left it at its implicit
        // width, hugging the popup's left edge — pin to full content width
        Layout.fillWidth: true
        Layout.preferredWidth: root.baseWidth
        Layout.maximumWidth: root.baseWidth
        visible: active
        height: active ? implicitHeight : 0
        Layout.preferredHeight: height

        sourceComponent: TimerView {}
    }
}
