pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.themes

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property var pam

    readonly property bool unlocking: unlockAnim.running

    color: "transparent"

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
        implicitWidth: cardCol.implicitWidth + 60
        implicitHeight: cardCol.implicitHeight + 60

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
            radius: 24
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
            width: parent.width - 60
            spacing: 20

            // ── lock icon ──
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "\uf023"
                color: Themes.accent
                font { pixelSize: 28; family: "Symbols Nerd Font Mono" }
            }

            // ── hostname ──
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: QuickState.hostName
                color: Themes.fg
                font { pixelSize: 16; family: "Quicksand"; bold: true; letterSpacing: 2 }
            }

            // ── accent line ──
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 40
                implicitHeight: 2
                radius: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: Themes.accent }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            // ── clock ──
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Text {
                    id: lockTimeText
                    Layout.alignment: Qt.AlignHCenter
                    color: Themes.fg
                    font { pixelSize: 42; family: "ZedMono Nerd Font"; bold: true }

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

                Text {
                    id: lockDateText
                    Layout.alignment: Qt.AlignHCenter
                    color: Themes.dim
                    font { pixelSize: 11; family: "Quicksand"; bold: true; letterSpacing: 1 }

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
            }

            // ── password input ──
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(parent.width, 220)
                Layout.preferredHeight: 36
                radius: 18
                color: Themes.cardBg
                border.width: 1
                border.color: passInput.activeFocus
                    ? Themes.accent
                    : pam.state === 2 ? "#ff5555"
                    : Themes.borderColor

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    Text {
                        text: "\uf023"
                        color: Themes.muted
                        font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                    }

                    TextInput {
                        id: passInput

                        Layout.fillWidth: true
                        clip: true
                        color: Themes.fg
                        font { pixelSize: 13; family: "Quicksand" }
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

            // ── now playing ──
            Item {
                id: np

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(cardCol.width - 20, 300)
                visible: !!MprisState.player

                readonly property bool isBrowser: MprisState.isBrowserPlayer(MprisState.player)
                readonly property real pct: {
                    npTick.tick;
                    return MprisState.progress(MprisState.player, npState, MprisState.player?.isPlaying ?? false);
                }
                property var npState: MprisState.progressState()

                implicitHeight: row.implicitHeight + 16

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
                    radius: 14
                    color: Themes.cardBg
                    border.width: 1
                    border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.16)
                }

                RowLayout {
                    id: row

                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    // art / glyph tile
                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 9
                        color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.12)

                        Image {
                            id: artImg
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(80, 80)
                            source: np.isBrowser ? "" : String(MprisState.player?.trackArtUrl ?? "")
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: artImg.status !== Image.Ready
                            text: np.isBrowser ? MprisState.browserGlyph(MprisState.player) : "\uf001"
                            color: Themes.accent
                            font { pixelSize: 14; family: "Symbols Nerd Font Mono" }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: MprisState.player?.trackTitle || "Unknown Track"
                            color: Themes.fg
                            elide: Text.ElideRight
                            font { pixelSize: 11; bold: true; family: "Quicksand" }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: MprisState.player?.trackArtist || (MprisState.player?.identity ?? "")
                            color: Themes.dim
                            elide: Text.ElideRight
                            font { pixelSize: 9; family: "Quicksand" }
                        }

                        // thin progress line
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 3
                            implicitHeight: 2
                            radius: 1
                            color: Qt.rgba(1, 1, 1, 0.12)

                            Rectangle {
                                readonly property real frac: np.pct
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * frac
                                height: parent.height
                                radius: 1
                                color: Themes.accent
                            }
                        }
                    }
                }
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
