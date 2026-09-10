import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import qs.services
import qs.customItems
import qs.themes

// Git bar module (v2) — monitors any number of worktrees (dots-style bare
// repos included via an optional stored worktree) with one cheap shared probe.
//
// · icon color = worst state across all repos (clean → no upstream → unpushed →
//   modified / staged → unreachable)
// · left click opens the monitor popup, right = push all, shift+middle = commit all
// · popup lists every repo with per-repo commit / push / pull / delete, bulk
//   actions, and a one-line "add a repo" form
// · untracked files are never scanned — only tracked staged/modified changes
// · failed actions explain themselves and point at the cli
BarBlock {
    id: gitPill

    required property var host

    property bool popupOpen: false

    onClicked: mouse => {
        if ((mouse.modifiers & Qt.AltModifier) && (mouse.button === Qt.LeftButton))
            ResourcesState.resourcesVisible = !ResourcesState.resourcesVisible;
        else if (mouse.button === Qt.LeftButton)
            gitPill.popupOpen = !gitPill.popupOpen;
        else if (mouse.button === Qt.RightButton)
            pushAll();
        else if ((mouse.modifiers & Qt.ShiftModifier) && (mouse.button === Qt.MiddleButton))
            commitAll();
    }

    function commitAll() {
        for (let i = 0; i < GitState.repos.length; i++)
            GitState.commitRepo(i, gitPill.commitMsg);
    }

    function pushAll() {
        for (let i = 0; i < GitState.repos.length; i++)
            GitState.pushRepo(i);
    }

    function pullAll() {
        for (let i = 0; i < GitState.repos.length; i++)
            GitState.pullRepo(i);
    }

    // ── state → color/label mapping (shared severity scale) ──
    readonly property var sevColors: [Themes.muted           // 0 waiting for first probe
        , Themes.green           // 1 clean & synced
        , Themes.sevNoUpstream   // 2 no upstream configured
        , Themes.sevUnpushed     // 3 unpushed (ahead) / behind
        , Themes.orange          // 4 modified
        , Themes.yellow          // 5 staged
        , Themes.red             // 6 unreachable repo
    ]

    readonly property color pillColor: gitPill.sevColors[GitState.worstSeverity]

    function stateColor(idx) {
        const s = GitState.statuses["i:" + idx];
        const sev = GitState.severityOf(s);
        if (sev === 3 && s) {
            if (s.ahead > 0 && s.behind > 0)
                return Themes.sevDiverged;
            if (s.ahead > 0)
                return Themes.sevUnpushed;
            return Themes.pink;
        }
        return gitPill.sevColors[sev];
    }

    function stateLabel(idx) {
        const s = GitState.statuses["i:" + idx];
        if (!s)
            return "…";
        if (s.error)
            return "unreachable";
        const parts = [];
        if (s.flags.includes("s"))
            parts.push("staged");
        if (s.flags.includes("u"))
            parts.push("modified");
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

    function repoRemoteText(idx) {
        const s = GitState.statuses["i:" + idx];
        if (!s)
            return "";
        const host = GitState.remoteLabel(s.remote);
        const br = String(s.branch ?? "");
        if (host && br)
            return host + " · " + br;
        if (host)
            return host;
        if (br)
            return br;
        return "";
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
            anchor.rect.y: gitPill.host.height + 8
            visible: gitPill.popupOpen
            grabFocus: true
            color: "transparent"
            implicitWidth: 430
            implicitHeight: Math.min(gitPopupCol.implicitHeight + 28, 440)

            onVisibleChanged: {
                GitState.monitoring = visible;
                gitPill.commitMsg = "";
                if (visible)
                    GitState.refresh();
            }

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
                                visible: GitState.repos.length > 0
                                text: `${GitState.repos.length} repo${GitState.repos.length === 1 ? "" : "s"}`
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

                        // ── bulk actions ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: GitState.repos.length > 0

                            MiniBtn {
                                text: "commit all"
                                tint: Themes.accent2
                                onClicked: {
                                    gitPill.commitMsg = "";
                                    gitPill.commitAll();
                                }
                            }
                            MiniBtn {
                                text: "push all"
                                tint: Themes.green
                                onClicked: gitPill.pushAll()
                            }
                            MiniBtn {
                                text: "pull all"
                                tint: Themes.yellow
                                onClicked: gitPill.pullAll()
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        // ── optional commit message — used by every commit
                        // button while it has text; empty falls back to the
                        // auto generic message ──
                        Field {
                            id: commitMsgField

                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            placeholder: "commit message (optional — otherwise \"chore: auto-sync\")"
                            onTextChanged: gitPill.commitMsg = commitMsgField.text
                        }

                        // ── repo rows ──
                        Repeater {
                            model: GitState.repos

                            delegate: GitRepoRow {
                                Layout.fillWidth: true
                                displayTitle: GitState.displayName(index)
                                subTitle: GitState.repos[index].workTree ?? GitState.repos[index].path
                                idx: index
                                dotColor: gitPill.stateColor(index)
                                stateText: gitPill.stateLabel(index)
                                remoteText: gitPill.repoRemoteText(index)
                                hint: GitState.statuses["i:" + index]?.hint ?? ""
                                commitMsg: gitPill.commitMsg
                            }
                        }

                        Text {
                            visible: GitState.repos.length === 0
                            Layout.fillWidth: true
                            text: "no repos tracked — add one below"
                            color: Themes.muted
                            font {
                                pixelSize: 9
                                family: "ZedMono Nerd Font"
                            }
                            Layout.topMargin: 4
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
                                    text: "Add repo"
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
                                    text: "path = an existing repo folder (worktree or dots-style bare) · upstream = remote ref to compare (optional) · worktree = only when the path is a bare git dir over a checkout (e.g. dots)"
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

                                Field {
                                    id: repoPathField
                                    Layout.fillWidth: true
                                    placeholder: "repo path (e.g. ~/projects/shibuya)"
                                    onReturnPressed: gitPill.doAddRepo()
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Field {
                                        id: repoUpField
                                        Layout.fillWidth: true
                                        placeholder: "upstream ref (optional)"
                                        onReturnPressed: gitPill.doAddRepo()
                                    }
                                    Field {
                                        id: repoWtField
                                        Layout.fillWidth: true
                                        placeholder: "worktree (only for bare, optional)"
                                        onReturnPressed: gitPill.doAddRepo()
                                    }
                                    MiniBtn {
                                        text: "add"
                                        onClicked: gitPill.doAddRepo()
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "only modified/staged tracked files are reported — untracked files are ignored"
                                    color: Themes.muted
                                    font {
                                        pixelSize: 8
                                        family: "ZedMono Nerd Font"
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
    property string addError: ""
    property string commitMsg: ""

    function doAddRepo() {
        const ok = GitState.addRepo(repoPathField.text, repoUpField.text, repoWtField.text);
        if (ok) {
            repoPathField.text = "";
            repoUpField.text = "";
            repoWtField.text = "";
            gitPill.addError = "";
            GitState.refresh();
        } else {
            gitPill.addError = "enter a non-duplicate repo path";
        }
    }
}
