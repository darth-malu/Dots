import QtQuick
import QtQuick.Layouts
import qs.themes

// small pill button used in git monitor popup (refresh / add / commit / …)
Rectangle {
    id: miniBtn

    property string text
    property string glyph
    property bool active: false
    property color tint: Themes.accent

    signal clicked

    implicitWidth: contentRow.implicitWidth + 12
    implicitHeight: 18
    radius: height / 2

    color: mouse.containsMouse || miniBtn.active
        ? Qt.rgba(miniBtn.tint.r, miniBtn.tint.g, miniBtn.tint.b, 0.18)
        : Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    border.color: mouse.containsMouse
        ? Qt.rgba(miniBtn.tint.r, miniBtn.tint.g, miniBtn.tint.b, 0.45)
        : Qt.rgba(1, 1, 1, 0.08)

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 3

        Text {
            visible: miniBtn.glyph != ""
            text: miniBtn.glyph
            color: miniBtn.active || mouse.containsMouse ? Qt.lighter(miniBtn.tint, 1.25) : Themes.dim
            font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
        }

        Text {
            visible: miniBtn.text != ""
            text: miniBtn.text
            color: miniBtn.active || mouse.containsMouse ? Qt.lighter(miniBtn.tint, 1.25) : Themes.dim
            font { pixelSize: 9; family: "Quicksand Medium" }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: miniBtn.clicked()
    }
}