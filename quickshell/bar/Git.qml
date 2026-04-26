import QtQuick
import QtQml
import Quickshell.Io
import Quickshell
import qs.customItems
import qs.themes

BarBlock {
    id: gitButton

    property var gitLoc: {
        const home = "/home/malu";
        const configDir = ["doom", "quickshell"].map(conf => `${home}/.config/${conf}`);
        const homeDir = ["Shibuya", "Development", "Documents/IMPORTANT/Org"].map(path => `${home}/${path}`);
        return [...configDir, ...homeDir];
    }

    property bool isDirty: false

    property bool isUntracked: false

    property bool isRunning: false // New: Track if a command is active

    property bool isCommited: false

    onClicked: mouse => {
        if (isRunning)
            return; // Ignore clicks while a sync is in progress
        if (mouse.button === Qt.LeftButton)
            commitOrPush("commit");
        else if (mouse.button === Qt.RightButton)
            commitOrPush("push");
    }

    content: BarText {
        text: ""               // 
        pointSize: 13
        color: {
            if (gitButton.isRunning)
                return 'cyan';
            return gitButton.isUntracked ? "yellow" : gitButton.isDirty ? "fuchsia" : 'grey';
        }
    }

    function commitOrPush(arg) {
        gitButton.isRunning = true;

        gitButton.gitLoc.forEach(location => {
            let checkCmd = `[ -n "$(git -C "${location}" status --porcelain)" ]`;
            let cleanPath = " " + location.split("/").pop();

            let iconDir = "/home/malu/.config/quickshell/assets";
            let icon = gitButton.isDirty ? `${iconDir}/gitRed.png` : `${iconDir}/gitBlack.png`;

            let notifyCmd = `notify-send -i "${icon}" "Git" "Processing ${cleanPath}"`;

            if (arg === "commit") {
                let commit = `${checkCmd} && git -C "${location}" add . && git -C "${location}" commit -m "++AutoCommit++" && notify-send -i "${icon}" "Git" "Commited ${cleanPath}" || true`;
                Quickshell.execDetached(["sh", "-c", commit]);
                // TODO add logic
            } else if (arg === "push") {
                let push = `git -C "${location}" push && notify-send -i "${icon}" "Git" "Pushed: ${cleanPath}" || true`;
                Quickshell.execDetached(["sh", "-c", push]);
            }
        });
        cooldownTimer.start();
    }

    Timer {
        id: cooldownTimer
        interval: 1000
        repeat: false
        running: false
        onTriggered: {
            gitButton.isRunning = false;
            gitStatusProcess.running = true;
            gitButton.isDirty = false;
            gitButton.isUntracked = false;
        }
    }

    Process {
        id: gitStatusProcess
        command: ["sh", "-c", gitButton.gitLoc.map(loc => `git -C "${loc}" status --porcelain`).join("; ")]
        running: false

        stdout: SplitParser {
            onRead: data => {
                data = data.trim();
                // Quickshell.execDetached(["notify-send", data]);
                if (data.trim().length > 0) {
                    if (data.startsWith("?"))
                        gitButton.isUntracked = true;
                    else
                        gitButton.isDirty = true;
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!gitButton.isRunning) {
                gitButton.isDirty = false;
                gitButton.isUntracked = false;
                gitStatusProcess.running = true;
            }
        }
    }
}
