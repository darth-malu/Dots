pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: volumeSingleton

    property bool shouldShowOsd: false
    property var defaultSink: Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource
    property var isAudioNode: defaultSink?.audio
    property bool isMuted: isAudioNode?.muted ?? false

    property string wih: "wow its working"
}
