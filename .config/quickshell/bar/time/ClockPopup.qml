import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.themes
import qs.services
import qs.customItems

ColumnLayout {
    id: root
    spacing: 3

    signal dayClicked(int day)

    BarText {
        font: Themes.quicksand
        color: Themes.calendarHeader
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDateTime(TimeService.currentDate, "MMMM yyyy")
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
        month: TimeService.currentDate.getMonth()
        year: TimeService.currentDate.getFullYear()

        delegate: Item {
            implicitWidth: 28
            implicitHeight: 28

            Rectangle {
                id: todayCircle
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: width / 2
                visible: model.today
                color: "black"
                opacity: 0.4
                border.width: 1
                border.color: 'fuchsia'
            }

            Text {
                anchors.centerIn: parent
                text: model.day
                font: Themes.quicksand
                color: {
                    if (model.today)
                        return Themes.calendarDayRow;
                    if (model.month === grid.month)
                        return "#b19cd9";
                    return "#4a3f5d";
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dayClicked(model.day)
            }
        }
    }
}
