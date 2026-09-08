import QtQuick
import QtQuick.Layouts
import qs.services
import qs.themes
import qs.customItems

// one git repo row in the monitor popup: status dot + name + state, with
// per-repo commit/push and delete; bare repos additionally get the cheap
// untracked-scan toggle (dots walks the whole home tree, so it's OFF by
// default)
RowLayout {
    id: row

    property string displayTitle
    property string subTitle
    property string kind
    property int idx
    property color dotColor
    property string stateText
    property bool canUntoggle: false

    spacing: 8
    Layout.preferredHeight: 30

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

        Text {
            text: row.displayTitle
            color: Themes.fg
            font { pixelSize: 11; bold: true; family: "Quicksand Medium" }
        }

        Text {
            visible: row.subTitle != ""
            text: row.subTitle
            elide: Text.ElideRight
            color: Themes.muted
            font { pixelSize: 8; family: "ZedMono Nerd Font" }
            Layout.maximumWidth: 190
        }
    }

    Item { Layout.fillWidth: true; Layout.minimumWidth: 8 }

    Text {
        visible: row.stateText != ""
        text: row.stateText
        color: row.dotColor
        font { pixelSize: 8; family: "ZedMono Nerd Font" }
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideMiddle
        Layout.maximumWidth: 92
    }

    MiniBtn {
        visible: row.canUntoggle
        glyph: (GitState.bareRepos[row.idx]?.untracked ?? false) ? "\uf0c2" : "\uf07c"
        active: GitState.bareRepos[row.idx]?.untracked ?? false
        onClicked: GitState.setBareUntracked(row.idx, !(GitState.bareRepos[row.idx]?.untracked ?? false))
    }

    MiniBtn {
        glyph: "\uea86"
        tint: Themes.accent2
        onClicked: GitState.commitRepo(row.kind, row.idx)
    }

    MiniBtn {
        glyph: "\uea77"
        tint: Themes.green
        onClicked: GitState.pushRepo(row.kind, row.idx)
    }

    MiniBtn {
        glyph: "\uf1f8"
        tint: Themes.red
        onClicked: {
            if (row.kind === "r")
                GitState.removeRegular(row.idx);
            else
                GitState.removeBare(row.idx);
        }
    }
}