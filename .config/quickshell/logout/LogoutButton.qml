import QtQuick
import Quickshell.Io
import qs.services
import qs.themes

QtObject {
	required property string command
	required property string text
	required property string icon
	property var keybind: null
	// single letter shown in the overlay's keycap hint
	property string keybindChar: ""
	// hover / active accent for the circular button
	property color accent: Themes.accent
	// optional custom action — when set, exec() calls it instead of command
	property var action: null

	id: button

	readonly property var process: Process {
		command: ["sh", "-c", button.command]
	}

	function exec() {
		if (button.action) {
			button.action();
			return;
		}
		process.startDetached();
		MiscState.logoutOpen = false;
	}
}