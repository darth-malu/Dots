pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Single source of truth for the git bar module.
// · repo list (regular worktrees + bare repos) persisted to git-prefs.json
// · one shared shell passthrough measures ALL repos per tick (cheap: a single
//   process spawn — vs. the old design spawning a git per repo every poll)
// · bare repos with a huge worktree (e.g. dots over ~/) skip the expensive
//   untracked scan by default, matching the `dots` alias
Singleton {
    id: root

    // ── defaults (only applied the very first run, before any user edits) ──
    readonly property var defaultBare: [
        { alias: "dots", dir: "/home/malu/Projects/Dots", workTree: "/home/malu", upstream: "gitlab/main", untracked: true }
    ]
    readonly property var defaultRegular: []

    readonly property var regularRepos: prefs.regular ?? []
    readonly property var bareRepos: prefs.bare ?? []

    function ensureDefaults() {
        if ((prefs.regular?.length ?? 0) === 0 && (prefs.bare?.length ?? 0) === 0) {
            prefs.regular = root.defaultRegular;
            prefs.bare = root.defaultBare;
            gitStore.writeAdapter();
        }
    }

    // ── repo add / remove (persisted) ──
    function _expand(p) {
        let s = String(p ?? "").trim();
        if (s === "~" ) {
            return Quickshell.env("HOME");
        } else if (s.startsWith("~/")) {
            return Quickshell.env("HOME") + s.slice(1);
        }
        return s.replace(/\/+$/, "");
    }

    function addRegular(path, upstream) {
        const p = root._expand(path);
        if (p.length === 0)
            return false;
        if (regularRepos.some(r => r.path === p))
            return false;
        prefs.regular = [...regularRepos, { path: p, upstream: String(upstream ?? "").trim() }];
        gitStore.writeAdapter();
        return true;
    }

    function removeRegular(idx) {
        if (idx < 0 || idx >= regularRepos.length)
            return;
        prefs.regular = regularRepos.filter((_, i) => i !== idx);
        gitStore.writeAdapter();
    }

    function addBare(alias, dir, workTree, upstream, untracked) {
        const a = String(alias ?? "").trim();
        const d = root._expand(dir);
        const w = root._expand(workTree);
        if (!a || !d || !w)
            return false;
        if (bareRepos.some(r => r.dir === d))
            return false;
        prefs.bare = [...bareRepos, {
            alias: a,
            dir: d,
            workTree: w,
            upstream: String(upstream ?? "").trim(),
            untracked: !!untracked
        }];
        gitStore.writeAdapter();
        return true;
    }

    function removeBare(idx) {
        if (idx < 0 || idx >= bareRepos.length)
            return;
        prefs.bare = bareRepos.filter((_, i) => i !== idx);
        gitStore.writeAdapter();
    }

    function setBareUntracked(idx, val) {
        if (idx < 0 || idx >= bareRepos.length)
            return;
        const next = [];
        for (let i = 0; i < bareRepos.length; i++) {
            next.push(i === idx
                ? { alias: bareRepos[i].alias, dir: bareRepos[i].dir, workTree: bareRepos[i].workTree, upstream: bareRepos[i].upstream, untracked: !!val }
                : bareRepos[i]);
        }
        prefs.bare = next;
        gitStore.writeAdapter();
    }

    // ── live status ──
    // statuses: "r:0" | "b:1" -> { flags, ahead, behind, upstream, error }
    property var statuses: ({})
    property bool busy: false
    property bool monitoring: false
    property int tick: 0

    readonly property int totalRepos: regularRepos.length + bareRepos.length

    // worst repo severity drives the bar icon colour
    readonly property int worstSeverity: {
        let worst = 0;
        for (const key in root.statuses) {
            const s = root.statuses[key];
            const sev = GitState.severityOf(s);
            if (sev > worst)
                worst = sev;
        }
        return worst;
    }

    function severityOf(s) {
        if (!s)
            return 0;
        if (s.error)
            return 6;
        if (s.flags.includes("s"))
            return 5;
        if (s.flags.includes("u") || s.flags.includes("t"))
            return 4;
        if (s.upstream && (s.ahead > 0 || s.behind > 0))
            return 3;
        if (s.upstream)
            return 1;
        return 2;
    }

    // one shared sh pass — status + ahead/behind for every repo in a single
    // process; --untracked-files=no keeps the home-tree bare repo cheap
    readonly property string probeScript: `
while [ "$#" -gt 0 ]; do
  kind="$1"; idx="$2"; shift 2
  p=""; dir=""; wt=""; up=""; uno="n"
  case "$kind" in
    r)
      p="$1"; up="$2"; shift 2
      [ -d "$p/.git" ] || [ -f "$p/.git" ] || { printf '%s\t%s\t\t%s\n' "r" "$idx" "err"; continue; }
      G() { git -C "$p" "$@"; }
      ;;
    b)
      alias="$1"; dir="$2"; wt="$3"; up="$4"; uno="$5"; shift 5
      [ -d "$dir" ] || { printf '%s\t%s\t\t%s\n' "b" "$idx" "err"; continue; }
      G() { git --git-dir="$dir" --work-tree="$wt" "$@"; }
      ;;
    *) continue ;;
  esac

  extra=""
  [ "$uno" = "y" ] && extra="--untracked-files=no"
  st=$(G status --porcelain=v1 $extra 2>/dev/null)
  flags=""
  if [ -n "$st" ]; then
    printf '%s\n' "$st" | grep -qE '^[MADRC]' && flags="\${flags}s"
    printf '%s\n' "$st" | grep -qE '^.[MD]' && flags="\${flags}u"
    printf '%s\n' "$st" | grep -qE '^\?\?' && flags="\${flags}t"
  fi

  ref="@{u}"
  [ -n "$up" ] && ref="$up"
  ab=$(G rev-list --count --left-right "$ref"...HEAD 2>/dev/null)
  [ -n "$ab" ] || ab="none"
  printf '%s\t%s\t%s\t%s\n' "$kind" "$idx" "$flags" "\${ab//	/:}"
done
`

    function buildArgs() {
        const args = [];
        for (let i = 0; i < root.regularRepos.length; i++) {
            const r = root.regularRepos[i];
            args.push("r", String(i), r.path, r.upstream ?? "");
        }
        for (let i = 0; i < root.bareRepos.length; i++) {
            const r = root.bareRepos[i];
            args.push("b", String(i), r.alias, r.dir, r.workTree, r.upstream ?? "", r.untracked ? "y" : "n");
        }
        return args;
    }

    // cheap-nothing if a probe is already in flight or there are no repos
    function refresh() {
        if (root.busy || root.totalRepos === 0)
            return;
        root.tick++;
        gitProc.tick = root.tick;
        gitProc.buf = "";
        gitProc.command = ["sh", "-c", root.probeScript, "sh"].concat(root.buildArgs());
        gitProc.running = true;
    }

    // ── commit / push (per-repo and bulk, refresh afterwards) ──
    // returns the git argv prefix: ["git","-C",path] or ["git","--git-dir=..","--work-tree=.."]
    function gitFor(kind, idx, sub) {
        let prefix = null;
        if (kind === "r") {
            const repo = root.regularRepos[idx];
            if (repo)
                prefix = ["git", "-C", repo.path];
        } else {
            const repo = root.bareRepos[idx];
            if (repo)
                prefix = ["git", "--git-dir=" + repo.dir, "--work-tree=" + repo.workTree];
        }
        if (!prefix)
            return null;
        return sub.length ? [...prefix, ...sub] : prefix;
    }

    function commitRepo(kind, idx) {
        const base = root.gitFor(kind, idx, []);
        if (!base)
            return;
        const name = root.displayName(kind, idx);
        const script = `"$@" add . 2>/dev/null && "$@" commit -m "++AutoCommit++" 2>/dev/null && notify-send -a quickshell "Git" "committed ${name}" || true`;
        Quickshell.execDetached(["sh", "-c", script, "sh", ...base]);
        root.pokeRefresh(2500);
    }

    function pushRepo(kind, idx) {
        const base = root.gitFor(kind, idx, []);
        if (!base)
            return;
        const name = root.displayName(kind, idx);
        const script = `"$@" push 2>/dev/null && notify-send -a quickshell "Git" "pushed ${name}" || notify-send -a quickshell "Git" "push failed: ${name}"`;
        Quickshell.execDetached(["sh", "-c", script, "sh", ...base]);
        root.pokeRefresh(2500);
    }

    function displayName(kind, idx) {
        if (kind === "r") {
            const repo = root.regularRepos[idx];
            return repo ? repo.path.split("/").filter(Boolean).pop() : "";
        }
        const repo = root.bareRepos[idx];
        return repo ? repo.alias : "";
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

    // ── persistence ──
    FileView {
        id: gitStore

        path: Quickshell.env("HOME") + "/.config/quickshell/git-prefs.json"
        // The default FileView preload is async: it starts a background read that can
        // land AFTER the user already added a repo (or after ensureDefaults wrote the
        // defaults), silently clobbering the adapter with stale on-disk data. Forcing
        // a synchronous read (blockLoading) + an explicit reload in onCompleted makes
        // the persisted list available before any code can touch it.
        preload: false
        blockLoading: true
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: prefs
            property var regular: []
            property var bare: []
        }
    }

    // poll only while the module is visible — the popup also refreshes on open
    Timer {
        interval: 60000
        running: root.monitoring
        repeat: true
        triggeredOnStart: true
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
            root.busy = true;
            const map = {};
            const lines = gitProc.buf.split("\n");
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i];
                if (line.length === 0)
                    continue;
                const f = line.split("\t");
                if (f.length < 3)
                    continue;
                const key = f[0] + ":" + f[1];
                const flags = f[2] || "";
                const ab = f[3];
                if (ab === "err") {
                    map[key] = { flags: "", ahead: -1, behind: -1, upstream: false, error: true };
                    continue;
                }
                let ahead = 0;
                let behind = 0;
                let upstream = true;
                if (ab === "none") {
                    upstream = false;
                } else {
                    const p = ab.split(":");
                    behind = parseInt(p[0], 10) || 0;
                    ahead = parseInt(p[1], 10) || 0;
                }
                map[key] = { flags, ahead, behind, upstream, error: false };
            }
            root.statuses = map;
            root.busy = false;
        }
    }

    Component.onCompleted: {
        gitStore.reload();
        ensureDefaults();
    }
}