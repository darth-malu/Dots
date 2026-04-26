pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property bool pipewireReady: Pipewire.ready

    readonly property PwNode outputSink: Pipewire.defaultAudioSink
    readonly property PwNode inputSink: Pipewire.defaultAudioSource

    // readonly property bool isCrusherWireless: inputSink.name == "bluez_input.D0:8A:55:44:68:A2"
    readonly property bool isCrusherWireless: inputSink.description == "Crusher Wireless"

    readonly property string inputVolume: Pipewire.ready ? isCrusherWireless ? (inputSink.audio.muted ? "❌" : `${Math.floor(inputSink.audio.volume * 100)}`) : "" : ""

    readonly property string outputVolume: Pipewire.ready ? root.outputSink.audio.muted ? "❌" : `${Math.floor(root.outputSink.audio.volume * 100)}` : ""

    PwObjectTracker {
        objects: [root.outputSink, root.inputSink]
    }
}
