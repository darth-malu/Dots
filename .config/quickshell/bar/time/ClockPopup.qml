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

    function clearSelection() {
        selectedDay = -1;
        selectedMonth = -1;
        selectedYear = -1;
        inputVisible = false;
        taskField.text = "";
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
                onClicked: {
                    root.clearSelection();
                    if (root.displayMonth === 0) {
                        root.displayMonth = 11;
                        root.displayYear -= 1;
                    } else {
                        root.displayMonth -= 1;
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        BarText {
            Layout.alignment: Qt.AlignHCenter
            font: Themes.quicksand
            color: Themes.calendarHeader
            text: Qt.formatDateTime(
                new Date(root.displayYear, root.displayMonth, 1),
                "MMMM yyyy"
            )
            pointSize: 13
        }

        Item { Layout.fillWidth: true }

        Text {
            text: ""
            color: Themes.calendarHeader
            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.clearSelection();
                    if (root.displayMonth === 11) {
                        root.displayMonth = 0;
                        root.displayYear += 1;
                    } else {
                        root.displayMonth += 1;
                    }
                }
            }
        }
    }

    DayOfWeekRow {
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
                    if (model.today) return "#1e1e2e";
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
                    color: "#cdd6f4"
                    font { pixelSize: 10; family: "Quicksand"; bold: true }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "\uf00d"
                    color: "#585b70"
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
                color: "#cdd6f4"
                placeholderTextColor: "#585b70"
                font { pixelSize: 11; family: "Quicksand" }
                background: Rectangle {
                    radius: 6
                    color: "#313244"
                    border.color: taskField.activeFocus ? Themes.calendarToday : "#45475a"
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
