pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.themes
import qs.customItems
import qs.bar.quicksettings.nowplaying

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property var pam

    readonly property bool unlocking: unlockAnim.running

    color: "transparent"

    // ── power buttons — nested inline component (declared before use) ──
    component LockPowerBtn: Rectangle {
        property string glyph: ""
        property color tint: Themes.accent
        property string cmd: ""
        implicitWidth: 46
        implicitHeight: 42
        radius: 14
        color: pwrMa.containsMouse ? Qt.rgba(tint.r, tint.g, tint.b, 0.18) : Qt.rgba(tint.r, tint.g, tint.b, 0.07)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        border.width: pwrMa.containsMouse ? 1 : 0
        border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.35)

        Text {
            anchors.centerIn: parent
            text: glyph
            color: pwrMa.containsMouse ? tint : Qt.rgba(tint.r, tint.g, tint.b, 0.8)
            font { pixelSize: 16; family: "Symbols Nerd Font Mono" }
        }

        MouseArea {
            id: pwrMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["sh", "-c", cmd])
        }
    }

    // ── unlock animation ──
    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            NumberAnimation { target: lockContent; property: "scale"; to: 0; duration: 200; easing.type: Easing.InBack }
            NumberAnimation { target: lockContent; property: "opacity"; to: 0; duration: 180 }
            NumberAnimation { target: background; property: "opacity"; to: 0; duration: 300 }
        }
        PropertyAction { target: root.lock; property: "locked"; value: false }
    }

    Connections {
        function onUnlock(): void {
            unlockAnim.start();
        }
        target: root.lock
    }

    // ── blurred screencopy background ──
    Item {
        id: background
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }

        ScreencopyView {
            id: screencopy
            anchors.fill: parent
            captureSource: root.screen
        }
    }

    // ── dark overlay ──
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    // ── lock content card ──
    Item {
        id: lockContent

        anchors.centerIn: parent
        implicitWidth: Math.min(root.width - 120, 680)
        implicitHeight: cardCol.implicitHeight + 76

        // entrance animation
        scale: 0
        rotation: 180

        Component.onCompleted: {
            entranceAnim.start();
        }

        ParallelAnimation {
            id: entranceAnim

            running: true

            NumberAnimation { target: lockContent; property: "scale"; from: 0; to: 1; duration: 500; easing.type: Easing.OutBack }
            NumberAnimation { target: lockContent; property: "rotation"; from: 180; to: 360; duration: 600; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: cardBg

            anchors.fill: parent
            radius: 28
            color: Qt.rgba(Themes.panelBg.r, Themes.panelBg.g, Themes.panelBg.b, 0.85)
            border.width: 1
            border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.3)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.6
                shadowColor: Qt.rgba(0, 0, 0, 0.5)
                shadowOpacity: 0.5
            }
        }

        ColumnLayout {
            id: cardCol

            anchors.centerIn: parent
            width: parent.width - 76
            spacing: 22

            // ── clock ──
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Text {
                    id: lockTimeText
                    Layout.alignment: Qt.AlignHCenter
                    color: Themes.fg
                    font { pixelSize: 56; family: "ZedMono Nerd Font"; bold: true }

                    function updateTime() {
                        var now = new Date();
                        var h = now.getHours();
                        var m = now.getMinutes();
                        text = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
                    }

                    Component.onCompleted: updateTime()

                    Timer {
                        interval: 1000
                        repeat: true
                        running: true
                        onTriggered: lockTimeText.updateTime()
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    Text {
                        id: lockDateText
                        color: Themes.dim
                        font { pixelSize: 13; family: "Quicksand"; bold: true; letterSpacing: 1 }

                        function updateDate() {
                            var now = new Date();
                            var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
                            var months = ["January", "February", "March", "April", "May", "June",
                                "July", "August", "September", "October", "November", "December"];
                            text = days[now.getDay()] + "  " + months[now.getMonth()] + " " + now.getDate();
                        }

                        Component.onCompleted: updateDate()

                        Timer {
                            interval: 60000
                            repeat: true
                            running: true
                            onTriggered: lockDateText.updateDate()
                        }
                    }

                    // ── separator dot ──
                    Text {
                        text: "\u2022"
                        color: Themes.separator
                        font { pixelSize: 9; family: "Quicksand" }
                    }

                    // ── elapsed time since the surface locked ──
                    Text {
                        id: lockElapsedText

                        property int startSec: 0

                        color: Themes.muted
                        font { pixelSize: 11; family: "ZedMono Nerd Font" }

                        function fmt(sec) {
                            const h = Math.floor(sec / 3600);
                            const m = Math.floor((sec % 3600) / 60);
                            const s = sec % 60;
                            if (h > 0)
                                return h + "h " + (m < 10 ? "0" : "") + m + "m";
                            if (m > 0)
                                return m + "m " + (s < 10 ? "0" : "") + s + "s";
                            return s + "s";
                        }
                        function refresh() {
                            if (lockElapsedText.startSec <= 0)
                                return;
                            const now = Math.floor(Date.now() / 1000);
                            text = "locked for " + lockElapsedText.fmt(Math.max(0, now - lockElapsedText.startSec));
                        }

                        Component.onCompleted: {
                            lockElapsedText.startSec = Math.floor(Date.now() / 1000);
                            lockElapsedText.refresh();
                        }

                        Timer {
                            interval: 1000
                            repeat: true
                            running: true
                            onTriggered: lockElapsedText.refresh()
                        }
                    }
                }
            }

            // ── accent line ──
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 56
                implicitHeight: 2
                radius: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: Themes.accent }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            // ── upcoming tasks + media, side by side ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // ── upcoming tasks ──
                Item {
                    id: tasks

                    Layout.fillWidth: true
                    Layout.preferredHeight: 182

                    function whenLabel(r) {
                        if (r.date === ReminderState.todayKey && r.time)
                            return r.time;
                        if (!r.time)
                            return r.date === ReminderState.todayKey ? "all day" : tasks.daySafe(r.date);
                        return tasks.daySafe(r.date);
                    }
                    function daySafe(d) {
                        const p = d.split("-");
                        if (p.length < 3)
                            return d;
                        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                        return months[parseInt(p[1]) - 1] + " " + parseInt(p[2]);
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Themes.cardBg
                        border.width: 1
                        border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.14)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 8

                        // header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "\uf0a1" // bell
                                color: Themes.accent
                                font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
                            }

                            Text {
                                text: "Upcoming"
                                color: Themes.fg
                                font { pixelSize: 11; family: "Quicksand"; bold: true; letterSpacing: 2 }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: ReminderState.upcoming.length > 0 ? ReminderState.upcoming.length : ""
                                color: Themes.dim
                                font { pixelSize: 10; bold: true; family: "ZedMono Nerd Font" }
                            }
                        }

                        // rows
                        Repeater {
                            id: taskList

                            model: ReminderState.upcoming.slice(0, 4)
                            visible: tasksView.count > 0

                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.preferredWidth: 78
                                    Layout.alignment: Qt.AlignVCenter
                                    text: tasks.whenLabel(modelData)
                                    color: modelData.date === ReminderState.todayKey ? Themes.accent : Themes.dim
                                    fontSizeMode: Text.HorizontalFit
                                    minimumPixelSize: 7
                                    font { pixelSize: 9; family: "ZedMono Nerd Font" }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 3
                                    Layout.preferredHeight: 12
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 1.5
                                    color: modelData.date === ReminderState.todayKey
                                        ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.7)
                                        : Qt.rgba(Themes.dim.r, Themes.dim.g, Themes.dim.b, 0.4)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: modelData.text
                                    color: Themes.fg
                                    elide: Text.ElideRight
                                    font { pixelSize: 10; family: "Quicksand" }
                                }
                            }
                        }

                        // empty state
                        Text {
                            id: tasksView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: ReminderState.upcoming.length === 0
                            text: "No upcoming tasks"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: Themes.muted
                            font { pixelSize: 10; family: "Quicksand"; italic: true }
                            opacity: 0.7
                        }
                    }
                }

                // ── now playing — redesigned, larger, with seek strip ──
                Item {
                    id: np

                    Layout.fillWidth: true
                    Layout.preferredHeight: 182
                    visible: !!MprisState.player

                    readonly property bool isBrowser: MprisState.isBrowserPlayer(MprisState.player)
                    readonly property var p: MprisState.player
                    readonly property color brand: MprisState.brandColor(np.p) ?? Themes.accent
                    readonly property real pct: {
                        npTick.tick;
                        return MprisState.progress(np.p, npState, np.p?.isPlaying ?? false);
                    }
                    property var npState: MprisState.progressState()

                    // volume mirrors the quicksettings now playing card — MPRIS
                    // volume where supported, otherwise the real per-app pipewire
                    // stream (chrome etc.) so the lock edits the actual settings
                    readonly property bool mprisVolume: np.p?.volumeSupported ?? false
                    readonly property var extNode: {
                        if (!np.p || np.p.volumeSupported)
                            return null;
                        return PipewireState.appStreamForPlayer(np.p);
                    }
                    readonly property bool muted: mprisVolume ? (np.p.volume <= 0) : (np.extNode?.audio?.muted ?? false)
                    readonly property real volume: mprisVolume ? (np.p.volume ?? 0) : (np.extNode?.audio?.volume ?? 0)

                    function fmtS(sec) {
                        if (!(sec > 0))
                            return "0:00";
                        const s = Math.floor(sec);
                        const m = Math.floor(s / 60);
                        const ss = s % 60;
                        return m + ":" + (ss < 10 ? "0" : "") + ss;
                    }

                    Timer {
                        id: npTick
                        interval: 1000
                        repeat: true
                        running: np.visible
                        property int tick: 0
                        onTriggered: tick++
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Themes.cardBg
                        border.width: 1
                        border.color: Qt.rgba(np.brand.r, np.brand.g, np.brand.b, 0.22)
                        Behavior on border.color {
                            ColorAnimation { duration: 300 }
                        }
                    }

                    ColumnLayout {
                        id: npCol
                        anchors.fill: parent
                        anchors.topMargin: 12
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 22   // clears the floor-line strip
                        spacing: 8

                        // ── art / title / time ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                implicitWidth: 52
                                implicitHeight: 52
                                radius: 13
                                color: Qt.rgba(np.brand.r, np.brand.g, np.brand.b, 0.14)
                                border.width: 1
                                border.color: Qt.rgba(np.brand.r, np.brand.g, np.brand.b, 0.3)

                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize: Qt.size(100, 100)
                                    source: np.isBrowser ? "" : String(MprisState.player?.trackArtUrl ?? "")
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: artImg.status !== Image.Ready
                                    text: np.isBrowser ? MprisState.browserGlyph(MprisState.player) : "\uf001"
                                    color: np.brand
                                    font { pixelSize: 17; family: "Symbols Nerd Font Mono" }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                MarqueeText {
                                    Layout.fillWidth: true
                                    text: MprisState.player?.trackTitle || "Unknown Track"
                                    textColor: Themes.fg
                                    fontFamily: "Quicksand"
                                    fontBold: true
                                    pixelSize: 13
                                    maxWidth: npCol.width - 96
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: MprisState.player?.trackArtist || (MprisState.player?.identity ?? "")
                                    color: Themes.dim
                                    elide: Text.ElideRight
                                    font { pixelSize: 10; family: "Quicksand" }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    text: np.fmtS(np.p?.position ?? 0) + " / " + np.fmtS(np.p?.length ?? 0)
                                    color: Themes.muted
                                    font { pixelSize: 9; bold: true; family: "ZedMono Nerd Font" }
                                }
                            }
                        }

                        // ── transport — prev · play/pause · next ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item { Layout.fillWidth: true }
                            TrackButton {
                                text: "\uf048"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                onClicked: {
                                    try { np.p?.previous(); } catch (e) {}
                                }
                            }
                            TrackButton {
                                text: (np.p?.isPlaying ?? false) ? "\uf04c" : "\uf04b"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                onClicked: {
                                    try { np.p?.togglePlaying(); } catch (e) {}
                                }
                            }
                            TrackButton {
                                text: "\uf050"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                onClicked: {
                                    try { np.p?.next(); } catch (e) {}
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        // ── volume — mute · slider · readout ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: 8
                                color: volMuteMa.containsMouse ? Qt.rgba(np.brand.r, np.brand.g, np.brand.b, 0.22) : np.muted ? Qt.rgba(np.brand.r, np.brand.g, np.brand.b, 0.15) : Qt.rgba(np.brand.r, np.brand.g, np.brand.b, 0.06)

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                border.width: np.muted || volMuteMa.containsMouse ? 1 : 0
                                border.color: Qt.rgba(np.brand.r, np.brand.g, np.brand.b, 0.3)

                                Text {
                                    anchors.centerIn: parent
                                    text: np.muted ? "\uf026" : "\uf028"
                                    color: np.muted ? Themes.muted : np.brand
                                    font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                                }

                                MouseArea {
                                    id: volMuteMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: MprisState.toggleMute(np.p)
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20

                                // groove
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 5
                                    radius: 2.5
                                    color: Qt.rgba(1, 1, 1, 0.1)

                                    // fill
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width * Math.max(0, Math.min(np.volume, 1))
                                        height: parent.height
                                        radius: 2.5
                                        color: np.muted ? Qt.rgba(0.38, 0.45, 0.64, 0.35) : Qt.rgba(np.brand.r, np.brand.g, np.brand.b, 0.55)
                                    }

                                    MouseArea {
                                        id: volBarMa
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        function setFromMouse(mx) {
                                            if (!np.p)
                                                return;
                                            const frac = Math.max(0, Math.min(mx / width, 1));
                                            if (np.mprisVolume)
                                                np.p.volume = frac;
                                            else if (np.extNode)
                                                np.extNode.audio.volume = frac;
                                        }
                                        onPressed: mouse => setFromMouse(mouse.x)
                                        onPositionChanged: mouse => {
                                            if (mouse.buttons & Qt.LeftButton)
                                                setFromMouse(mouse.x);
                                        }
                                        onWheel: wheel => {
                                            if (np.p)
                                                MprisState.adjustVolume(np.p, wheel.angleDelta.y > 0);
                                            wheel.accepted = true;
                                        }
                                    }
                                }
                            }

                            Text {
                                text: `${Math.round(np.volume * 100)}%`
                                color: np.muted ? Themes.dim : Themes.fg
                                font { pixelSize: 10; bold: true; family: "ZedMono Nerd Font" }
                            }
                        }
                    }

                    // ── floor-line seek strip (same language as the card) ──
                    SeekStrip {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        ratio: np.pct
                        accent: np.brand
                        length: np.p?.length ?? 0
                        onSeeked: frac => {
                            try {
                                if (np.p && np.p.length > 0)
                                    np.p.position = frac * np.p.length;
                            } catch (e) {}
                        }
                    }
                }
            }

            // ── power controls ──
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                // sleep / reboot / shutdown / exit
                LockPowerBtn { glyph: "\uf186"; tint: Themes.accent; cmd: "systemctl suspend" }
                LockPowerBtn { glyph: "\uf021"; tint: "#50fa7b"; cmd: "systemctl reboot" }
                LockPowerBtn { glyph: "\uf011"; tint: "#ff5555"; cmd: "systemctl poweroff" }
                LockPowerBtn { glyph: "\uf08b"; tint: "#e6db74"; cmd: "loginctl terminate-user $USER" }
            }

            // ── password input ──
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(cardCol.width, 320)
                Layout.preferredHeight: 40
                radius: 20
                color: Themes.cardBg
                border.width: 1
                border.color: passInput.activeFocus
                    ? Themes.accent
                    : pam.state === 2 ? "#ff5555"
                    : Themes.borderColor

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }

                TextInput {
                    id: passInput

                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    verticalAlignment: TextInput.AlignVCenter
                    color: Themes.fg
                    font { pixelSize: 14; family: "Quicksand" }
                    echoMode: TextInput.Password
                    passwordCharacter: "\u2022"
                    selectByMouse: true
                    selectionColor: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.3)
                    focus: true

                    Keys.onReturnPressed: submitPassword()
                    Keys.onEnterPressed: submitPassword()
                    Keys.onEscapePressed: passInput.text = ""
                }
            }

            // ── state message ──
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: pam.lockMessage.length > 0 || pam.state === 1 || pam.state === 2 || pam.state === 3
                text: {
                    if (pam.lockMessage.length > 0)
                        return pam.lockMessage;
                    if (pam.state === 1) return "Error";
                    if (pam.state === 2) return "Too many attempts";
                    if (pam.state === 3) return "Authentication failed";
                    return "";
                }
                color: pam.state === 2 ? "#ff5555" : Themes.muted
                font { pixelSize: 10; family: "Quicksand"; bold: true }
                horizontalAlignment: Text.AlignHCenter
            }

            // ── hint ──
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Enter password to unlock"
                color: Themes.muted
                font { pixelSize: 9; family: "Quicksand" }
                opacity: 0.6
            }
        }
    }

    function submitPassword(): void {
        if (passInput.text.length === 0)
            return;
        pam.start(passInput.text);
        passInput.text = "";
    }
}