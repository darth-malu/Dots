import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.themes
import qs.services
import qs.customItems

ColumnLayout {
    id: root
    spacing: 6

    signal taskSubmitted(int day, int month, int year, string task)

    property int displayMonth: TimeService.currentDate.getMonth()
    property int displayYear: TimeService.currentDate.getFullYear()

    property int selectedDay: -1
    property int selectedMonth: -1
    property int selectedYear: -1
    property bool inputVisible: false
    property bool yearView: false

    function clearSelection() {
        selectedDay = -1;
        selectedMonth = -1;
        selectedYear = -1;
        inputVisible = false;
        taskField.text = "";
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

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: ""
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

            // click the title to switch between month and full-year view
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.clearSelection();
                    root.yearView = !root.yearView;
                }
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: ""
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
        visible: !root.yearView
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
        visible: !root.yearView
        Layout.fillWidth: true
        Layout.fillHeight: true
        month: root.displayMonth
        year: root.displayYear

        delegate: Item {
            implicitWidth: 30
            implicitHeight: 30

            property bool hovered: false

            readonly property bool isTracked: {
                MiscState.trackedDatesRev;
                return MiscState.isTrackedDate(model.year, model.month, model.day);
            }

            readonly property bool isSelected: model.day === root.selectedDay
                && model.month === root.selectedMonth
                && model.year === root.selectedYear

            Rectangle {
                width: 28
                height: 28
                anchors.centerIn: parent
                radius: width / 2
                visible: model.today && !parent.isSelected
                color: Themes.calendarToday
                opacity: 0.85
            }

            Rectangle {
                width: 28
                height: 28
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
                    if (model.today) return "#282a36";
                    if (parent.hovered) return Themes.calendarToday;
                    if (model.month === grid.month) return Themes.calendarActiveMonth;
                    return Themes.calendarInactiveMonth;
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                width: 4
                height: 4
                radius: width / 2
                color: Themes.calendarActiveMonth
                visible: parent.isTracked
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onClicked: {
                    root.selectedDay = model.day;
                    root.selectedMonth = model.month;
                    root.selectedYear = model.year;
                    root.inputVisible = true;
                    taskField.forceActiveFocus();
                }
            }
        }
    }

    // ── Full-year view (toggle via the title) ──
    GridLayout {
        visible: root.yearView
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 8
        rowSpacing: 10

        Repeater {
            model: 12

            ColumnLayout {
                id: miniMonth

                required property int index

                spacing: 1

                Text {
                    text: Qt.formatDateTime(new Date(2000, miniMonth.index, 1), "MMM")
                    color: root.displayMonth === miniMonth.index ? Themes.calendarToday : Themes.calendarHeader
                    font { pixelSize: 9; bold: true; family: "Quicksand" }
                    Layout.alignment: Qt.AlignHCenter
                }

                MonthGrid {
                    month: miniMonth.index
                    year: root.displayYear
                    spacing: 0
                    Layout.fillWidth: true

                    delegate: Item {
                        implicitWidth: 11
                        implicitHeight: 12

                        readonly property bool isTrackedMini: {
                            MiscState.trackedDatesRev;
                            return MiscState.isTrackedDate(model.year, model.month, model.day);
                        }

                        Text {
                            anchors.centerIn: parent
                            text: model.day
                            font { pixelSize: 7; family: "Quicksand" }
                            color: model.today ? Themes.calendarToday : model.month === miniMonth.index ? Themes.calendarActiveMonth : Themes.calendarInactiveMonth
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 3
                            height: 3
                            radius: 1.5
                            color: Themes.calendarActiveMonth
                            visible: parent.isTrackedMini
                        }
                    }
                }

                // click a mini month to open it in month view
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.clearSelection();
                        root.displayMonth = miniMonth.index;
                        root.yearView = false;
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.inputVisible ? 48 : 0
        color: "transparent"
        clip: true
        visible: root.inputVisible

        ColumnLayout {
            anchors.fill: parent
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.preferredWidth: 4
                    Layout.preferredHeight: 14
                    radius: 2
                    color: Themes.calendarToday
                }

                Text {
                    text: {
                        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                        var dt = new Date(root.selectedYear, root.selectedMonth, root.selectedDay);
                        return days[dt.getDay()] + ", " + months[root.selectedMonth] + " " + root.selectedDay;
                    }
                    color: "#f8f8f2"
                    font { pixelSize: 10; family: "Quicksand"; bold: true }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "\uf00d"
                    color: "#6272a4"
                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearSelection()
                    }
                }
            }

            TextField {
                id: taskField
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                placeholderText: "Add a task..."
                color: "#f8f8f2"
                placeholderTextColor: "#6272a4"
                font { pixelSize: 11; family: "Quicksand" }
                background: Rectangle {
                    radius: 6
                    color: "#44475a"
                    border.color: taskField.activeFocus ? Themes.calendarToday : "#6272a4"
                    border.width: 1
                }
                leftPadding: 8
                rightPadding: 8
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: Text.AlignVCenter
                selectByMouse: true

                Keys.onReturnPressed: {
                    if (text.trim().length > 0) {
                        root.taskSubmitted(root.selectedDay, root.selectedMonth, root.selectedYear, text.trim());
                        root.clearSelection();
                    }
                }
                Keys.onEnterPressed: {
                    if (text.trim().length > 0) {
                        root.taskSubmitted(root.selectedDay, root.selectedMonth, root.selectedYear, text.trim());
                        root.clearSelection();
                    }
                }
                Keys.onEscapePressed: root.clearSelection()
            }
        }
    }
}
