import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import qs.services
import qs.customItems
import qs.themes

// Git bar module — monitors both bare repos (alias + gitdir + worktree) and
// regular worktrees with one cheap shared probe (see GitState).
//
// · icon color = worst state across all repos (clean/upstream → staged →
//   modified/untracked → unpushed → failed)
// · left click opens the monitor popup, right = push all,
//   middle = toggle the RHS performance modules, shift+middle = commit all
// · popup lists every repo with its state, per-repo commit/push, delete, and
//   an "add" form for new regular/bare repo locations
BarBlock {
    id: gitPill

    required property var host

    property bool popupOpen: false

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            gitPill.popupOpen = !gitPill.popupOpen;
        else if (mouse.button === Qt.RightButton)
            pushAll();
        else if ((mouse.modifiers & Qt.ShiftModifier) && (mouse.button === Qt.MiddleButton))
            commitAll();
        else if (mouse.button === Qt.MiddleButton)
            ResourcesState.resourcesVisible = !ResourcesState.resourcesVisible;
    }

    // keep the module stale-proof while the pill is actually on screen
    onVisibleChanged: GitState.monitoring = visible
    Component.onCompleted: GitState.monitoring = visible

    function commitAll() {
        for (let i = 0; i < GitState.regularRepos.length; i++)
            GitState.commitRepo("r", i);
        for (let i = 0; i < GitState.bareRepos.length; i++)
            GitState.commitRepo("b", i);
    }

    function pushAll() {
        for (let i = 0; i < GitState.regularRepos.length; i++)
            GitState.pushRepo("r", i);
        for (let i = 0; i < GitState.bareRepos.length; i++)
            GitState.pushRepo("b", i);
    }

    // ── state → color/label mapping (shared severity scale) ──
    readonly property var sevColors: [Themes.muted           // 0 waiting for first probe
        , Themes.green           // 1 clean & synced
        , "#8a8fa1"              // 2 no upstream configured
        , "#8be9fd"              // 3 unpushed (ahead)
        , "#ffb86c"              // 4 unstaged/untracked
        , "#f5c86a"              // 5 staged
        , Themes.red              // 6 unreachable repo
    ]

    readonly property color pillColor: gitPill.sevColors[GitState.worstSeverity]

    function stateColor(kind, idx) {
        const s = GitState.statuses[kind + ":" + idx];
        const sev = GitState.severityOf(s);
        if (sev === 3 && s) {
            if (s.ahead > 0 && s.behind > 0)
                return "#ffd866";
            if (s.ahead > 0)
                return "#8be9fd";
            return Themes.pink;
        }
        return gitPill.sevColors[sev];
    }

    function stateLabel(kind, idx) {
        const s = GitState.statuses[kind + ":" + idx];
        if (!s)
            return "…";
        if (s.error)
            return "unreachable";
        const parts = [];
        if (s.flags.includes("s"))
            parts.push("staged");
        if (s.flags.includes("u"))
            parts.push("modified");
        if (s.flags.includes("t"))
            parts.push("untracked");
        if (parts.length === 0) {
            if (!s.upstream)
                return "no upstream";
            if (s.ahead > 0 && s.behind > 0)
                return `↑${s.ahead} · ↓${s.behind}`;
            if (s.ahead > 0)
                return `↑${s.ahead} unpushed`;
            if (s.behind > 0)
                return `↓${s.behind} behind`;
            return "clean · synced";
        }
        return parts.join(" + ");
    }

    content: BarText {
        text: "\uf1d3"
        pointSize: 13
        color: gitPill.pillColor
    }

    LazyLoader {
        loading: gitPill.popupOpen

        PopupWindow {
            id: gitPopup

            anchor.window: gitPill.host
            anchor.rect.x: {
                let g = gitPill.mapToGlobal(0, 0);
                return Math.max(4, Math.min(g.x + gitPill.width / 2 - width / 2, gitPill.host.width - width - 4));
            }
            anchor.rect.y: 35
            visible: gitPill.popupOpen
            grabFocus: true
            color: "transparent"
            implicitWidth: 400
            implicitHeight: Math.min(gitPopupCol.implicitHeight + 28, 420)

            onVisibleChanged: if (visible)
                GitState.refresh()

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Themes.popupCardBg
                border.width: 1
                border.color: Themes.borderMuted

                Keys.onEscapePressed: gitPill.popupOpen = false
                focus: true

                ScrollView {
                    id: gitScroll
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    contentWidth: gitPopupCol.width

                    ColumnLayout {
                        id: gitPopupCol

                        width: gitScroll.availableWidth
                        spacing: 6

                        // ── header ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "\uf1d3"
                                color: gitPill.pillColor
                                font {
                                    pixelSize: 12
                                    family: "Symbols Nerd Font Mono"
                                    bold: true
                                }
                            }

                            Text {
                                text: "Git"
                                color: Themes.fg
                                font {
                                    pixelSize: 12
                                    bold: true
                                    family: "Quicksand Medium"
                                }
                            }

                            Text {
                                visible: GitState.regularRepos.length > 0 || GitState.bareRepos.length > 0
                                text: `${GitState.regularRepos.length + GitState.bareRepos.length} repo${GitState.regularRepos.length + GitState.bareRepos.length === 1 ? "" : "s"}`
                                color: Themes.muted
                                font {
                                    pixelSize: 9
                                    family: "ZedMono Nerd Font"
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            // refresh
                            MiniBtn {
                                glyph: "\uf021"
                                onClicked: GitState.refresh()
                            }

                            // add
                            MiniBtn {
                                glyph: "\u002b"
                                active: gitPill.showAdd
                                onClicked: gitPill.showAdd = !gitPill.showAdd
                            }

                            // close
                            MiniBtn {
                                glyph: "\uf00d"
                                tint: Themes.red
                                onClicked: gitPill.popupOpen = false
                            }
                        }

                        // ── repo rows (with section headers) ──
                        Text {
                            visible: GitState.regularRepos.length > 0
                            Layout.fillWidth: true
                            text: "WORKTREES"
                            color: Themes.muted
                            font {
                                pixelSize: 8
                                letterSpacing: 2
                                family: "ZedMono Nerd Font"
                            }
                            Layout.topMargin: 2
                        }

                        Repeater {
                            model: GitState.regularRepos

                            delegate: GitRepoRow {
                                Layout.fillWidth: true
                                displayTitle: modelData.path.split("/").filter(Boolean).pop()
                                subTitle: modelData.path
                                kind: "r"
                                idx: index
                                dotColor: gitPill.stateColor("r", index)
                                stateText: gitPill.stateLabel("r", index)
                                canUntoggle: false
                            }
                        }

                        Text {
                            visible: GitState.bareRepos.length > 0
                            Layout.fillWidth: true
                            text: "BARE"
                            color: Themes.muted
                            font {
                                pixelSize: 8
                                letterSpacing: 2
                                family: "ZedMono Nerd Font"
                            }
                            Layout.topMargin: GitState.regularRepos.length > 0 ? 6 : 2
                        }

                        Repeater {
                            model: GitState.bareRepos

                            delegate: GitRepoRow {
                                Layout.fillWidth: true
                                displayTitle: modelData.alias
                                subTitle: modelData.dir
                                kind: "b"
                                idx: index
                                dotColor: gitPill.stateColor("b", index)
                                stateText: gitPill.stateLabel("b", index)
                                canUntoggle: true
                            }
                        }

                        // ── add repo form ──
                        Rectangle {
                            Layout.fillWidth: true
                            visible: gitPill.showAdd
                            Layout.preferredHeight: addCol.implicitHeight + 16
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Themes.separator

                            ColumnLayout {
                                id: addCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Text {
                                    text: gitPill.addMode === "regular" ? "Add worktree" : "Add bare repo"
                                    color: Themes.fg
                                    font {
                                        pixelSize: 10
                                        bold: true
                                        family: "Quicksand Medium"
                                    }
                                }

                                // one-line usage hint so the form explains itself
                                Text {
                                    Layout.fillWidth: true
                                    text: gitPill.addMode === "regular" ? "path = an existing repo folder; upstream = remote to compare (optional)" : "alias = display name · dir = bare git dir · worktree = the checkout it tracks · untracked = scan for ?? files (slow over a tree like ~/)"
                                    color: Qt.rgba(Themes.muted.r, Themes.muted.g, Themes.muted.b, 1)
                                    font {
                                        pixelSize: 8
                                        family: "ZedMono Nerd Font"
                                    }
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: gitPill.addError !== ""
                                    text: "\uf071  " + gitPill.addError
                                    color: Themes.red
                                    font {
                                        pixelSize: 8
                                        family: "ZedMono Nerd Font"
                                    }
                                    wrapMode: Text.WordWrap
                                }

                                // mode switch
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    MiniBtn {
                                        text: "worktree"
                                        active: gitPill.addMode === "regular"
                                        onClicked: gitPill.addMode = "regular"
                                    }
                                    MiniBtn {
                                        text: "bare"
                                        active: gitPill.addMode === "bare"
                                        onClicked: gitPill.addMode = "bare"
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                // regular: path + optional upstream
                                ColumnLayout {
                                    visible: gitPill.addMode === "regular"
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Field {
                                        id: regPathField
                                        Layout.fillWidth: true
                                        placeholder: "repo path (e.g. ~/projects/foo)"
                                        onReturnPressed: gitPill.doAddRegular()
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Field {
                                            id: regUpField
                                            Layout.fillWidth: true
                                            placeholder: "upstream (optional)"
                                            onReturnPressed: gitPill.doAddRegular()
                                        }
                                        MiniBtn {
                                            text: "add"
                                            onClicked: gitPill.doAddRegular()
                                        }
                                    }
                                }

                                // bare: alias, gitdir, worktree, upstream, untracked toggle
                                ColumnLayout {
                                    visible: gitPill.addMode === "bare"
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Field {
                                        id: bareAliasField
                                        Layout.fillWidth: true
                                        placeholder: "alias (e.g. dots)"
                                        onReturnPressed: gitPill.doAddBare()
                                    }
                                    Field {
                                        id: bareDirField
                                        Layout.fillWidth: true
                                        placeholder: "bare git directory"
                                        onReturnPressed: gitPill.doAddBare()
                                    }
                                    Field {
                                        id: bareWtField
                                        Layout.fillWidth: true
                                        placeholder: "worktree path"
                                        onReturnPressed: gitPill.doAddBare()
                                    }
                                    Field {
                                        id: bareUpField
                                        Layout.fillWidth: true
                                        placeholder: "upstream (optional)"
                                        onReturnPressed: gitPill.doAddBare()
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        MiniBtn {
                                            text: "untracked scan"
                                            active: gitPill.addUntracked
                                            onClicked: gitPill.addUntracked = !gitPill.addUntracked
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        MiniBtn {
                                            text: "add"
                                            onClicked: gitPill.doAddBare()
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

    property bool showAdd: false
    property string addMode: "regular"
    property bool addUntracked: false
    property string addError: ""

    function doAddRegular() {
        const ok = GitState.addRegular(regPathField.text, regUpField.text);
        if (ok) {
            regPathField.text = "";
            regUpField.text = "";
            gitPill.addError = "";
            GitState.refresh();
        } else {
            gitPill.addError = "enter a non-duplicate repo path";
        }
    }

    function doAddBare() {
        const ok = GitState.addBare(bareAliasField.text, bareDirField.text, bareWtField.text, bareUpField.text, gitPill.addUntracked);
        if (ok) {
            bareAliasField.text = "";
            bareDirField.text = "";
            bareWtField.text = "";
            bareUpField.text = "";
            gitPill.addError = "";
            GitState.refresh();
        } else {
            gitPill.addError = "alias, bare dir and worktree are all required (no duplicates)";
        }
    }
}
