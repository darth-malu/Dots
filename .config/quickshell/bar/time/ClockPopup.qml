import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.themes
import qs.services
import qs.customItems

ColumnLayout {
    spacing: 3

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
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            // The Purple Circle
            Rectangle {
                id: todayCircle
                anchors.centerIn: parent
                width: 24  // Adjust size to fit your grid
                height: 24
                radius: width / 2 // Makes it a perfect circle

                // Only show if it's today
                visible: model.today

                // Purple color - using a slightly transparent version of your border color
                color: "black"
                opacity: 0.4  // Makes it a soft glow/background

                // Optional: Add a solid border to the circle
                border.width: 1
                border.color: 'fuchsia'
            }

            Text {
                anchors.centerIn: parent
                // horizontalAlignment: Text.AlignHCenter
                // verticalAlignment: Text.AlignVCenter
                text: model.day
                font: Themes.quicksand
                // Logic for text color
                color: {
                    if (model.today)
                        return Themes.calendarDayRow;

                    if (model.month === grid.month)
                        return "#b19cd9";
                    return "#4a3f5d";
                }
            }
        }
    }
}
