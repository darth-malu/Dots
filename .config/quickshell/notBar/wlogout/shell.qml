import QtQuick
import Quickshell

ShellRoot {
	WLogout {
		LogoutButton {
			command: "loginctl lock-session"
			keybind: Qt.Key_L
			text: "Lock"
			icon: "\uf023"
		}

		LogoutButton {
			command: "loginctl terminate-user $USER"
			keybind: Qt.Key_E
			text: "Logout"
			icon: "\uf08b"
		}

		LogoutButton {
			keybind: Qt.Key_T
			text: "Restart Timer"
			icon: "\uf021"
			timerCmd: "shutdown -r"
			presets: [5, 10, 15, 30, 45, 60, 120, 240]
		}

		LogoutButton {
			keybind: Qt.Key_Y
			text: "Shutdown Timer"
			icon: "\uf011"
			timerCmd: "shutdown -h"
			presets: [5, 10, 15, 30, 45, 60, 120, 240]
		}

		LogoutButton {
			command: "systemctl poweroff"
			keybind: Qt.Key_S
			text: "Shutdown"
			icon: "\uf011"
		}

		LogoutButton {
			command: "systemctl reboot"
			keybind: Qt.Key_R
			text: "Reboot"
			icon: "\uf021"
		}
	}
}
