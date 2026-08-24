pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels.values

    property string event: "workspace"

    // current hyprland submap name, "" when in the default map
    property string submap: ""

    readonly property var trackedSubmaps: ["resize", "drag"]

    // ── IPC bridge ──
    // Hyprland 0.56 routes every dispatch through its Lua API, so the legacy
    // "dispatch>" wire format (and with it quickshell's Hyprland.dispatch)
    // silently fails. This socket speaks the current "/dispatch <lua expr>"
    // form instead — verified working primitives only.
    readonly property string ipcPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/hypr/${Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")}/.socket.sock`

    // dispatches written while the bridge is down wait here; flushed in
    // order the moment the reconnect lands
    property var _pending: []

    Socket {
        id: ipc
        path: root.ipcPath
        connected: true

        // Hyprland 0.56 closes bridge connections after a request (or idle
        // timeout) — a constant `connected: true` binding does NOT re-fire,
        // so without this every dispatch after the first close silently dies
        onConnectionStateChanged: {
            console.log(`[scrolldbg] ipc conn=${connected}`);
            if (connected) {
                const q = root._pending.splice(0);
                for (let i = 0; i < q.length; i++)
                    ipc.write(q[i]);
                if (q.length > 0)
                    ipc.flush();
            }
        }
        onError: err => console.log(`[scrolldbg] ipc error=${err}`)
    }

    function dispatch(expr) {
        const line = `/dispatch ${expr}\n`;
        if (!ipc.connected) {
            root._pending.push(line);
            ipc.connected = true; // async — queued lines flush onConnected
            return;
        }
        ipc.write(line);
        ipc.flush();
    }

    // scroll-style relative stepping; up = previous workspace (m-1)
    function stepWorkspace(up) {
        dispatch(`hl.get_active_monitor():set_workspace("${up ? "m-1" : "m+1"}")`);
    }

    function gotoWorkspace(id) {
        dispatch(`hl.get_active_monitor():set_workspace(${parseInt(id)})`);
    }

    function handleSubmap(ev) {
        if (ev.name !== "submap")
            return;

        const name = ev.data ?? "";
        root.submap = (name === "" || name === "default") ? "" : name;
    }

    Connections {
        target: Hyprland

        function onRawEvent(ev) {
            root.handleSubmap(ev);
        }
    }

    // TEMP scroll/click diagnosis — remove with the [scrolldbg] logs
    IpcHandler {
        target: "hdbg"

        function step(up: bool): void {
            root.stepWorkspace(up);
        }
        function goto(id: int): void {
            root.gotoWorkspace(id);
        }
        function sock(): string {
            return `connected=${ipc.connected}`;
        }
    }
}
