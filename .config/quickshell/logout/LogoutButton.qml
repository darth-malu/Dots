import QtQuick
import Quickshell.Io
import qs.services

QtObject {
	required property string command
	required property string text
	required property string icon
	property var keybind: null
	// single letter shown in the overlay's keycap hint
	property string keybindChar: ""
	// hover / active accent for the circular button
	property color accent: "#bd93f9"

	id: button

	readonly property var process: Process {
		command: ["sh", "-c", button.command]
	}

	function exec() {
		process.startDetached();
		MiscState.logoutOpen = false;
	}
}
