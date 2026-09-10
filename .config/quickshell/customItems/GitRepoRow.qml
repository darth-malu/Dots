import QtQuick
import QtQuick.Layouts
import qs.services
import qs.themes
import qs.customItems

// one git repo row in the monitor popup: status dot + name + state, per-repo
// commit / push / pull and delete. A failed action surfaces a use-the-cli
// hint line under the name instead of dying silently.
RowLayout {
    id: row

    property string displayTitle
    property string subTitle
    property color dotColor
    property string stateText
    property int idx
    property string commitMsg: ""
    property string remoteText: ""
    property string hint: ""

    spacing: 8

    Rectangle {
        implicitWidth: 8
        implicitHeight: 8
        radius: 4
        color: row.dotColor
        Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 1
        Layout.maximumWidth: 210

        Text {
            text: row.displayTitle
            color: Themes.fg
            font {
                pixelSize: 11
                bold: true
                family: "Quicksand Medium"
            }
        }

        Text {
            visible: row.subTitle != ""
            text: row.subTitle
            elide: Text.ElideRight
            color: Themes.muted
            font {
                pixelSize: 8
                family: "ZedMono Nerd Font"
            }
            Layout.fillWidth: true
            Layout.maximumWidth: 210
        }

        Text {
            visible: row.hint != ""
            text: "\uf071  " + row.hint
            elide: Text.ElideMiddle
            color: Themes.red
            font {
                pixelSize: 8
                family: "ZedMono Nerd Font"
            }
            Layout.fillWidth: true
            Layout.maximumWidth: 210
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.minimumWidth: 8
    }

    Text {
        visible: row.remoteText != ""
        text: row.remoteText
        elide: Text.ElideRight
        color: Themes.muted
        font {
            pixelSize: 8
            family: "ZedMono Nerd Font"
        }
        Layout.maximumWidth: 96
        Layout.alignment: Qt.AlignVCenter
    }

    Text {
        visible: row.stateText != ""
        text: row.stateText
        elide: Text.ElideMiddle
        color: row.dotColor
        font {
            pixelSize: 8
            family: "ZedMono Nerd Font"
        }
        Layout.maximumWidth: 96
        Layout.alignment: Qt.AlignVCenter
    }

    MiniBtn {
        glyph: "\uea86"
        tint: Themes.accent2
        onClicked: GitState.commitRepo(row.idx, row.commitMsg)
    }

    MiniBtn {
        glyph: "\uea77"
        tint: Themes.green
        onClicked: GitState.pushRepo(row.idx)
    }

    MiniBtn {
        glyph: "\uf01e"
        tint: Themes.yellow
        onClicked: GitState.pullRepo(row.idx)
    }

    MiniBtn {
        glyph: "\uf1f8"
        tint: Themes.red
        onClicked: GitState.removeRepo(row.idx)
    }
}
