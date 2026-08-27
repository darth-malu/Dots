pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property bool pipewireReady: Pipewire.ready

    readonly property PwNode outputSink: Pipewire.defaultAudioSink
    readonly property PwNode inputSink: Pipewire.defaultAudioSource

    // EDIFIER R1280DB speakers hooked up to the onboard analog out
    readonly property string outputDisplayName: root.outputSink?.description === "Family 17h (Models 00h-0fh) HD Audio Controller Analog Stereo" ? "EDIFIER R1280DB" : root.outputSink?.description ?? ""

    // readonly property bool isCrusherWireless: inputSink.name == "bluez_input.D0:8A:55:44:68:A2"
    readonly property bool isCrusherWireless: inputSink.description == "Crusher Wireless"

    readonly property string inputVolume: Pipewire.ready ? isCrusherWireless ? (inputSink.audio.muted ? "❌" : `${Math.floor(inputSink.audio.volume * 100)}`) : "" : ""

    readonly property string outputVolume: Pipewire.ready ? root.outputSink.audio.muted ? "❌" : `${Math.floor(root.outputSink.audio.volume * 100)}` : ""

    // true for per-application audio *output* streams (spotify, chrome, ...),
    // as opposed to the sink itself or input/mic streams
    function isOutputApplicationStream(node) {
        if (!node)
            return false;
        if (!node.isStream)
            return false;
        return (node.type & PwNodeType.Flag.AudioOutStream) ? true : false;
    }

    // human-friendly label for a stream node
    function streamDisplayName(node) {
        if (!node)
            return "";
        if (node.nickname && node.nickname.length > 0)
            return node.nickname;
        if (node.description && node.description.length > 0)
            return node.description;
        const app = node.properties && node.properties["application.name"];
        if (app)
            return app;
        return node.name || "stream";
    }

    PwObjectTracker {
        objects: [root.outputSink, root.inputSink]
    }
}
