pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: root

    enum PamState {
        None,
        Error,
        MaxTries,
        Failed
    }

    required property WlSessionLock lock

    property string lockMessage
    property int state
    property int tries: 0
    property string buffer

    signal flashMsg

    PamContext {
        id: pamCtx

        config: "passwd"
        configDirectory: Quickshell.env("HOME") + "/.config/quickshell/assets/pam.d"

        onMessageChanged: {
            if (message.startsWith("The account is locked"))
                root.lockMessage = message;
            else if (root.lockMessage && message.endsWith(" left to unlock)"))
                root.lockMessage += "\n" + message;
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(root.buffer);
            root.buffer = "";
        }

        onCompleted: res => {
            if (res === PamResult.Success) {
                root.lock.unlock();
                return;
            }

            if (root.state !== Pam.MaxTries)
                root.state = Pam.None;

            if (res === PamResult.Error)
                root.state = Pam.Error;
            else if (res === PamResult.MaxTries)
                root.state = Pam.MaxTries;
            else if (res === PamResult.Failed) {
                root.tries++;
                if (root.tries >= 5)
                    root.state = Pam.MaxTries;
                else
                    root.state = Pam.Failed;
            }

            root.flashMsg();
            stateReset.restart();
        }
    }

    Timer {
        id: stateReset
        interval: 4000
        onTriggered: {
            if (root.state !== Pam.MaxTries)
                root.state = Pam.None;
        }
    }

    Connections {
        function onSecureChanged(): void {
            if (root.lock.secure) {
                root.buffer = "";
                root.state = Pam.None;
                root.lockMessage = "";
                root.tries = 0;
            }
        }

        function onUnlock(): void {
            pamCtx.abort();
        }

        target: root.lock
    }

    function start(password: string): void {
        if (root.state === Pam.MaxTries)
            return;
        root.buffer = password;
        pamCtx.start();
    }

    function abort(): void {
        pamCtx.abort();
    }
}
