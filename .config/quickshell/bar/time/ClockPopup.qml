import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.themes
import qs.services
import qs.customItems

ColumnLayout {
    id: root
    spacing: 6

    signal dayClicked(int day, int month, int year)

    property int displayMonth: TimeService.currentDate.getMonth()
    property int displayYear: TimeService.currentDate.getFullYear()

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: ""
            color: Themes.calendarHeader
            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
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
            text: ""
            color: Themes.calendarHeader
            font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
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

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: model.today ? Themes.calendarToday
                     : parent.hovered ? "#45475a"
                     : Qt.rgba(1, 1, 1, 0.04)
                opacity: model.today ? 0.5 : parent.hovered ? 1 : 1
                border {
                    width: model.today ? 2 : parent.hovered ? 1 : 0
                    color: model.today ? Themes.calendarToday : Qt.rgba(1, 1, 1, 0.1)
                }
            }

            Text {
                anchors.centerIn: parent
                text: model.day
                font: Themes.quicksand
                color: {
                    if (model.today) return "#1e1e2e";
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
                onClicked: root.dayClicked(model.day, model.month, model.year)
            }
        }
    }
}
