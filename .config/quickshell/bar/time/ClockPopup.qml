import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.themes
import qs.services
import qs.customItems

ColumnLayout {
    id: root
    spacing: 6

    signal dayClicked(int day)

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

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: model.today ? Themes.calendarToday : parent.hovered ? "#313244" : "transparent"
                opacity: model.today ? 0.3 : parent.hovered ? 1 : 0
            }

            Text {
                anchors.centerIn: parent
                text: model.day
                font: Themes.quicksand
                color: {
                    if (model.today) return Themes.calendarToday;
                    if (model.month === grid.month) return Themes.calendarActiveMonth;
                    return Themes.calendarInactiveMonth;
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
                onClicked: root.dayClicked(model.day)
            }
        }
    }
}
