import QtQuick
import Quickshell.Io
import qs.services

QtObject {
	required property string command
	required property string text
	required property string icon
	property var keybind: null

	// when set, clicking opens the duration slider instead of running a command;
	// timerCmd is the shutdown prefix ("shutdown -r" / "shutdown -h")
	property string timerCmd: ""

	id: button

	readonly property var process: Process {
		command: ["sh", "-c", button.command]
	}

	function exec() {
		process.startDetached();
		MiscState.logoutOpen = false;
	}
}
