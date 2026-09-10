pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Single source of truth for the git bar module.
// · repo list persisted to git-prefs.json: { path, workTree? }
//   - workTree only when path is a bare dotfiles-style git dir operated via
//     --git-dir/--work-tree instead of -C
// · one shared shell pass measures ALL repos per poll: status flags (incl.
//   untracked) + ahead/behind + branch + remote host in a single process
// · actions (commit/push/pull) run through a serialized Process queue that
//   captures stderr so failures surface a short hint instead of dying silently
Singleton {
    id: root

    // mutable repo list — reassigned on every mutation (never bound) so the
    // popup model repaints immediately after an add/remove
    property var repos: []
    property int repoRev: 0

    readonly property int pollMs: prefs.pollMs

    function _expand(p) {
        let s = String(p ?? "").trim();
        if (s === "~")
            return Quickshell.env("HOME");
        if (s.startsWith("~/"))
            return Quickshell.env("HOME") + s.slice(1);
        return s.replace(/\/+$/, "");
    }

    function _persist() {
        prefs.repos = root.repos.map(r => ({
            path: r.path,
            workTree: r.workTree ?? ""
        }));
        gitStore.writeAdapter();
    }

    function addRepo(path, workTree) {
        const p = root._expand(path);
        if (p.length === 0)
            return false;
        if (root.repos.some(r => r.path === p))
            return false;
        const entry = { path: p };
        const w = root._expand(workTree ?? "");
        if (w.length > 0)
            entry.workTree = w;
        root.repos = root.repos.concat(entry);
        root.repoRev++;
        root._persist();
        return true;
    }

    function removeRepo(idx) {
        if (idx < 0 || idx >= root.repos.length)
            return;
        root.repos = root.repos.filter((_, i) => i !== idx);
        root.repoRev++;
        root._persist();
    }

    // ── live status ──
    // statuses: "i:<idx>" -> { flags, ahead, behind, upstream, error, branch, remote, hint }
    property var statuses: ({})
    readonly property bool busy: gitProc.running || act.running
    property bool monitoring: false
    property int tick: 0

    readonly property int totalRepos: repos.length

    // worst repo severity drives the bar icon colour
    readonly property int worstSeverity: {
        let worst = 0;
        for (const key in root.statuses) {
            const sev = GitState.severityOf(root.statuses[key]);
            if (sev > worst)
                worst = sev;
        }
        return worst;
    }

    function severityOf(s) {
        if (!s)
            return 0;
        if (s.error)
            return 7;
        if (s.flags.includes("s"))
            return 6;
        if (s.flags.includes("u"))
            return 5;
        if (s.flags.includes("t"))
            return 4;
        if (s.upstream && (s.ahead > 0 || s.behind > 0))
            return 3;
        if (s.upstream)
            return 1;
        return 2;
    }

    // one shared sh pass covers every repo in a single process; per repo a
    // single `status -sb` yields flags AND ahead/behind. untracked shows as
    // `??` lines → "t" flag (dirs are collapsed, keeping large trees cheap).
    // gc.auto=0 + maintenance.auto=0 stop git self-triggering a repack.
    readonly property string probeScript: `
fail() { printf 'i\t%s\terr\tnone\t\t\n' "$1"; }
while [ "$#" -gt 0 ]; do
  p="$1"; wt="$2"; i="$3"; shift 3
  if [ -n "$wt" ]; then
    gitx() { git --git-dir="$p" --work-tree="$wt" -c gc.auto=0 -c maintenance.auto=0 "$@"; }
  else
    gitx() { git -C "$p" -c gc.auto=0 -c maintenance.auto=0 "$@"; }
  fi
  gitx rev-parse --git-dir >/dev/null 2>&1 || { fail "$i"; continue; }

  st=$(gitx status --porcelain=v1 -sb --untracked-files=normal 2>/dev/null)
  flags=""
  ab=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      "##"*) case "$line" in
                *"ahead"*|*"behind"*) ab=$(printf '%s' "$line" | awk '{ for(n=1;n<=NF;n++){ f=$n; gsub(/[^a-z]/,"",f); l=length(f); if(l>=5){ v=$(n+1); gsub(/[^0-9]/,"",v); if(substr(f,l-4)="ahead")a=v; if(substr(f,l-5)="behind")b=v } } } if(a=="")a=0; if(b=="")b=0; printf "B%s A%s", b, a }');;
                *"..."*) ab="B0 A0";;
              esac;;
      "??"*) flags="\${flags}t";;
      *) n="\${#line}"; [ "$n" -ge 2 ] || continue
         x="\${line:0:1}"; y="\${line:1:1}"
         case "$x" in M|A|D|R|C) flags="\${flags}s";; esac
         case "$y" in M|D) flags="\${flags}u";; esac;;
    esac
  done <<EOF
$st
EOF
  [ -n "$ab" ] || ab="none"
  br=$(gitx rev-parse --abbrev-ref HEAD 2>/dev/null)
  rm=$(gitx remote get-url origin 2>/dev/null)
  printf 'i\t%s\t%s\t%s\t%s\t%s\n' "$i" "$flags" "$ab" "$br" "$rm"
done
`

    function buildArgs() {
        const args = [];
        for (let i = 0; i < root.repos.length; i++) {
            const r = root.repos[i];
            args.push(r.path, r.workTree ?? "", String(i));
        }
        return args;
    }

    // probe on demand only — no background polling (unless the popup is open,
    // see the timer below)
    function refresh() {
        if (root.busy || root.totalRepos === 0)
            return;
        root.tick++;
        gitProc.tick = root.tick;
        gitProc.buf = "";
        gitProc.command = ["sh", "-c", root.probeScript, "sh"].concat(root.buildArgs());
        gitProc.running = true;
    }

    function repoPath(idx) {
        const r = root.repos[idx];
        return r ? r.path : "";
    }

    function displayName(idx) {
        const r = root.repos[idx];
        if (!r)
            return "";
        return r.path.split("/").filter(Boolean).pop();
    }

    // map a remote url to a short friendly name (github / gitlab / …)
    function remoteLabel(url) {
        let s = String(url ?? "");
        if (s.length === 0)
            return "";
        s = s.replace(/^ssh:\/\//, "").replace(/^https?:\/\//, "").replace(/^git:\/\//, "").replace(/^git@/, "").replace(/@/, "");
        const host = s.split("/")[0].split(":")[0].replace(/\/$/, "");
        const names = {
            "github.com": "github",
            "gitlab.com": "gitlab",
            "bitbucket.org": "bitbucket",
            "codeberg.org": "codeberg"
        };
        if (names[host])
            return names[host];
        return host.split(".")[0];
    }

    // ── actions: commit / push / pull ──
    // serialized through one Process so stderr is captured; a failed step sets
    // a per-repo `hint` shown in the popup + notify and aborts the rest of that
    // action's steps
    function prefixFor(idx) {
        const r = root.repos[idx];
        if (!r)
            return null;
        const wt = root._expand(r.workTree ?? "");
        if (wt.length > 0)
            return ["git", "--git-dir=" + r.path, "--work-tree=" + wt, "-c", "gc.auto=0", "-c", "maintenance.auto=0"];
        return ["git", "-C", r.path, "-c", "gc.auto=0", "-c", "maintenance.auto=0"];
    }

    function commitRepo(idx, msg) {
        const name = root.displayName(idx);
        const m = String(msg ?? "").trim() || "chore: auto-sync";
        root.queueSteps(idx, [
            {
                label: "commit",
                sub: ["add", "-u", "--", "."]
            },
            {
                label: "commit",
                sub: ["commit", "-m", m],
                ok: "committed " + name,
                err: "commit failed"
            }
        ]);
    }

    function pushRepo(idx) {
        const name = root.displayName(idx);
        root.queueSteps(idx, [
            {
                label: "push",
                sub: ["push"],
                ok: "pushed " + name,
                err: "push failed"
            }
        ]);
    }

    function pullRepo(idx) {
        const name = root.displayName(idx);
        root.queueSteps(idx, [
            {
                label: "pull",
                sub: ["pull", "--ff-only"],
                ok: "pulled " + name,
                err: "pull failed"
            }
        ]);
    }

    // ── serialized action runner ──
    property var _queue: []
    property int _group: 0

    function queueSteps(idx, steps) {
        root._group++;
        for (const s of steps)
            root._queue.push({
                group: root._group,
                idx,
                label: s.label ?? "",
                sub: s.sub,
                ok: s.ok ?? "",
                err: s.err ?? ""
            });
        root._kick();
    }

    function _kick() {
        if (act.running || act._skipGroup >= 0)
            return;
        if (root._queue.length === 0) {
            act._skipGroup = -1;
            return;
        }
        const a = root._queue.shift();
        act._cur = a;
        act.out = "";
        act.command = [...root.prefixFor(a.idx), ...a.sub];
        act.running = true;
    }

    function pokeRefresh(ms) {
        refreshTimer.interval = ms || 1200;
        refreshTimer.start();
        root.refresh();
    }

    Timer {
        id: refreshTimer
        interval: 1500
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: act
        property var _cur: null
        property int _skipGroup: -1
        property string out: ""
        running: false

        stdout: SplitParser {
            onRead: data => act.out += data + "\n"
        }
        stderr: SplitParser {
            onRead: data => act.out += data + "\n"
        }

        onExited: exitCode => {
            const a = act._cur;
            if (!a)
                return;
            const key = "i:" + a.idx;
            const name = root.displayName(a.idx);
            const upToDate = /(everything up-to-date|already up to date|up to date)/i.test(act.out);
            const nothingToCommit = /(nothing to commit|no changes added to commit)/i.test(act.out);
            if (exitCode === 0 || nothingToCommit) {
                const st = Object.assign({}, root.statuses[key]);
                st.hint = "";
                const map = Object.assign({}, root.statuses);
                map[key] = st;
                root.statuses = map;
                if (nothingToCommit)
                    notify("Git", name + ": nothing to commit");
                else if (upToDate && a.label === "push")
                    notify("Git", name + ": already up to date");
                else if (upToDate && a.label === "pull")
                    notify("Git", name + ": already up to date");
                else if (a.ok.length > 0)
                    notify("Git", a.ok);
            } else {
                const st = Object.assign({}, root.statuses[key]);
                st.hint = a.err;
                const map = Object.assign({}, root.statuses);
                map[key] = st;
                root.statuses = map;
                notify("Git", a.err || "command failed");
                // abort remaining steps of this action's group
                act._skipGroup = a.group;
                root._queue = root._queue.filter(x => x.group !== a.group);
            }
            act._cur = null;
            root.pokeRefresh(2200);
            // skip-mode ends once the rest of the group has been drained
            if (act._skipGroup >= 0 && !root._queue.some(x => x.group === act._skipGroup))
                act._skipGroup = -1;
            act.running = false;
            root._kick();
        }
    }

    function notify(app, msg) {
        Quickshell.execDetached(["notify-send", "-a", "quickshell", app, msg]);
    }

    // ── persistence ──
    FileView {
        id: gitStore

        path: Quickshell.env("HOME") + "/.config/quickshell/git-prefs.json"
        // synchronous read (blockLoading) + explicit reload in onCompleted make
        // the persisted list available before anything can touch it
        preload: false
        blockLoading: true
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: prefs
            property var repos: []
            property int pollMs: 60000
        }
    }

    function setPollMs(ms) {
        const v = Math.max(5000, Math.min(300000, ms));
        prefs.pollMs = v;
        gitStore.writeAdapter();
    }

    // while the popup is open, a slow configurable tick keeps the rows current
    Timer {
        interval: prefs.pollMs
        running: root.monitoring
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: gitProc
        property int tick: 0
        property string buf: ""
        running: false

        stdout: SplitParser {
            onRead: data => gitProc.buf += data + "\n"
        }

        onExited: {
            if (gitProc.tick !== root.tick)
                return;
            const map = {};
            const lines = gitProc.buf.split("\n");
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i];
                if (line.length === 0)
                    continue;
                const f = line.split("\t");
                if (f.length < 4)
                    continue;
                const key = "i:" + f[1];
                const flags = f[2] || "";
                if (flags === "err") {
                    map[key] = {
                        flags: "",
                        ahead: -1,
                        behind: -1,
                        upstream: false,
                        error: true,
                        branch: "",
                        remote: "",
                        hint: ""
                    };
                    continue;
                }
                const ab = f[3];
                let ahead = 0;
                let behind = 0;
                let upstream = true;
                if (ab === "none" || ab === "") {
                    upstream = false;
                } else {
                    // "B<n> A<n>" — behind then ahead, from the -b branch line
                    const bm = /B(\d+)/.exec(ab);
                    const am = /A(\d+)/.exec(ab);
                    behind = bm ? parseInt(bm[1], 10) : 0;
                    ahead = am ? parseInt(am[1], 10) : 0;
                }
                map[key] = {
                    flags,
                    ahead,
                    behind,
                    upstream,
                    error: false,
                    branch: f[4] ?? "",
                    remote: f[5] ?? "",
                    hint: ""
                };
            }
            root.statuses = map;
        }
    }

    Component.onCompleted: {
        gitStore.reload();
        root.repos = [...(prefs.repos ?? [])].map(r => ({
            path: String(r.path ?? ""),
            workTree: String(r.workTree ?? "")
        })).filter(r => r.path.length > 0);
    }
}