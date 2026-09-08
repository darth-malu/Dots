pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property alias lock: lock

    WlSessionLock {
        id: lock

        signal unlock

        LockSurface {
            lock: lock
            pam: pam
        }
    }

    Pam {
        id: pam
        lock: lock
    }

    // Force-load a screencopy early so the ICC backend is ready
    // when the lock surface needs it
    Loader {
        asynchronous: true
        active: true
        onLoaded: active = false

        sourceComponent: ScreencopyView {
            captureSource: Quickshell.screens[0]
        }
    }

    IpcHandler {
        function lock(): void {
            lock.locked = true;
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }

        target: "lock"
    }
}
