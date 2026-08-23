pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtMultimedia

Singleton {
    id: root

    property alias enabled: props.enabled
    readonly property alias enabledSince: props.enabledSince

    // toggle feedback — distinct chirp per direction plus a matching toast
    SoundEffect {
        id: sfxOn
        source: Qt.resolvedUrl("../wav/mixkit-positive-interface-beep-221.wav")
    }

    SoundEffect {
        id: sfxOff
        source: Qt.resolvedUrl("../wav/mixkit-censorship-beep-1082.wav")
    }

    function announce() {
        if (props.enabled) {
            sfxOn.play();
            Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "preferences-system-windows-effect", "Caffeine on", "Screen will stay awake"]);
        } else {
            sfxOff.play();
            Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "preferences-desktop-screensaver", "Caffeine off", "Idle sleep re-enabled"]);
        }
    }

    onEnabledChanged: {
        if (enabled)
            props.enabledSince = new Date();
        root.announce();
    }

    PersistentProperties {
        id: props
        property bool enabled
        property date enabledSince
        reloadableId: "idleInhibitor"
    }

    IdleInhibitor {
        enabled: props.enabled
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            anchors.right: true
            anchors.bottom: true
            color: "transparent"
            mask: Region {}
        }
    }

    function toggle() {
        enabled = !enabled;
    }

    IpcHandler {
        target: "idleInhibitor"

        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            root.toggle();
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }
    }
}
