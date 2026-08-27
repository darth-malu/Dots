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

    // true for per-application audio *playback* streams (spotify, chrome, ...):
    // output streams are flagged Sink (Audio | Sink | Stream), whereas the sink
    // itself is not a stream and input/mic capture streams are Audio | Source | Stream
    function isOutputApplicationStream(node) {
        if (!node)
            return false;
        return node.isStream === true && node.isSink === true;
    }

    // human-friendly label for a stream node
    function streamDisplayName(node) {
        if (!node)
            return "";
        if (node.nickname && node.nickname.length > 0 && node.nickname != node.name)
            return node.nickname;
        const d = (node.description || "").toLowerCase();
        const n = (node.name || "").toLowerCase();
        const app = node.properties && node.properties["application.name"];
        const a = (app || "").toLowerCase();
        // Discord's audio engine identifies as "WEBRTC VoiceEngine" (and has
        // no node.description), so match it no matter which field carries it.
        if (d.includes("webrtc") || n.includes("webrtc") || a.includes("webrtc"))
            return "discord";
        if (node.description && node.description.length > 0)
            return node.description;
        if (app && app.length > 0)
            return app;
        return node.name || "stream";
    }

    // reactive filtered list of per-app playback streams (spotify, chrome, ...)
    // derived from the whole node table; recomputes as streams come and go
    readonly property var appStreams: Pipewire.ready ? Pipewire.nodes.values.filter(n => root.isOutputApplicationStream(n)) : []

    // bind the app streams so their PwNodeAudio volume/mute are valid & writable
    // (unbound nodes reject volume changes with "not bound")
    PwObjectTracker {
        objects: root.appStreams
    }

    PwObjectTracker {
        objects: [root.outputSink, root.inputSink]
    }
}
