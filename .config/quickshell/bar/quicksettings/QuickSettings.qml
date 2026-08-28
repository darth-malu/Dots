import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

import qs.customItems
import qs.bar.quicksettings
import qs.bar.quicksettings.nowplaying
import qs.bar.quicksettings.power
import qs.services
import qs.themes

BarBlock {
    id: root

    required property var host

    property string hostName: QuickState.hostName

    property bool playerListOpen: false // reserved for a future chooser popup
    property bool showQsPopup: false
    property bool showPowerPopup: false
    property bool qsPopupArmed: false
    // 0 = hidden, 1 = reboot presets, 2 = shutdown presets
    property int timerPicker: 0
    property bool compactNowPlaying: true
    property bool shuffleOn: false
    property bool loopOn: false

    // debounce: ignore clicks briefly after opening so the same click
    // that opens the popup can't immediately close it
    property bool _openDebounce: false

    Timer {
        id: openDebounceTimer
        interval: 250
        repeat: false
        running: root._openDebounce
        onTriggered: root._openDebounce = false
    }

    // ── player chooser — hidden until the bottom-left region is hovered,
    // which reveals a small launcher button; clicking it expands the chip
    // strip (wheel steps through players, click pins) ──

    // ── volume OSD ──
    onLeftClicked: {
        if (_openDebounce)
            return;
        root.showQsPopup = !root.showQsPopup;
    }

    onShowQsPopupChanged: {
        MiscState.qsOpen = showQsPopup;
        if (showQsPopup) {
            _openDebounce = true;
            openDebounceTimer.restart();
            qsPopupArmed = false;
            Qt.callLater(() => qsPopupArmed = true);
        } else {
            qsPopupArmed = false;
        }
        if (!showQsPopup) {
            showPowerPopup = false;
            timerPicker = 0;
        }
    }

    // closing a menu closes all children too — hiding the power card
    // takes the restart/shutdown timer view with it
    onShowPowerPopupChanged: {
        if (!showPowerPopup)
            timerPicker = 0;
    }
    Component.onCompleted: MiscState.qsOpen = showQsPopup

    onRightClicked: MiscState.toggleSysTray = !MiscState.toggleSysTray
    onAltLeftClicked: MiscState.toggleSysTray = !MiscState.toggleSysTray

    Shortcut {
        sequence: "Escape"
        enabled: root.showQsPopup
        onActivated: root.showQsPopup = false
    }

    content: NixQuickSettings {}

    LazyLoader {
        loading: root.showQsPopup

        PopupWindow {
            id: quickSettingsPopup
            visible: root.showQsPopup
            grabFocus: false
            color: "transparent"

            anchor.window: root.host
            anchor.rect.x: {
                let g = root.mapToGlobal(0, 0);
                let cx = g.x + (root.width / 2) - (width / 2);
                const scrW = root.host?.screen?.width ?? 1920;
                return Math.max(6, Math.min(cx, scrW - width - 6));
            }
            anchor.rect.y: 33

            implicitWidth: 300
            implicitHeight: qsContent.implicitHeight

            Rectangle {
                id: qsCard
                anchors.fill: parent
                focus: true
                radius: 12
                color: Themes.popupCardBg
                border.width: 1
                border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.3)

                Keys.onEscapePressed: root.showQsPopup = false

                // rigid column — no scroll container, the popup grows with it
                ColumnLayout {
                    id: qsContent

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    spacing: 0

                    // ═══ CONTENT ═══
                    ColumnLayout {
                        id: contentCol
                        Layout.fillWidth: true
                        spacing: 0

                        // ═══ HEADER ═══
                        Card {
                            title: ""
                            icon: ""
                            accent: "transparent"
                            cardColor: "transparent"
                            cardPadding: 8
                            // cardPadding: 0
                            // x: 0
                            Layout.bottomMargin: 12

                            // ── header — three equal thirds, each centred:
                            // avatar · identity + uptime · controls ──
                            content: RowLayout {
                                id: headerRow

                                Layout.fillWidth: true
                                spacing: 10

                                // circular avatar — click to pick another picture
                                ClippingRectangle {
                                    id: avatarBox

                                    // hidden for now — assets and pickAvatar stay
                                    visible: true
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    radius: height / 2
                                    color: avatarMa.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.18) : Themes.separator
                                    border.width: 0

                                    // halo of light on hover
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 1)
                                        shadowBlur: 1.2
                                        autoPaddingEnabled: true
                                        shadowOpacity: avatarMa.containsMouse ? 1.0 : 0

                                        Behavior on shadowOpacity {
                                            NumberAnimation {
                                                duration: 200
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    Image {
                                        id: avatarImg

                                        anchors.fill: parent
                                        anchors.margins: 1
                                        source: MiscState.avatarUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf007"
                                        color: Themes.muted
                                        font {
                                            pixelSize: 16
                                            family: "Symbols Nerd Font Mono"
                                        }
                                        visible: avatarImg.status !== Image.Ready
                                    }

                                    MouseArea {
                                        id: avatarMa

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: MiscState.pickAvatar()
                                    }
                                }

                                Text {
                                    id: uptime
                                    Layout.alignment: Qt.AlignLeft
                                    text: ResourcesState.uptimeText.length > 0 ? ResourcesState.uptimeText : "…"
                                    color: Themes.muted
                                    font {
                                        pixelSize: 9
                                        bold: true
                                        family: "ZedMono Nerd Font"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                HeaderButton {
                                    glyph: "\uf0f4"
                                    tint: CaffeineService.enabled ? "#ffb86c" : Themes.muted

                                    onActivated: CaffeineService.toggle()
                                }

                                HeaderButton {
                                    glyph: "\uf013"
                                    tint: Themes.accent

                                    onActivated: {
                                        root.showQsPopup = false;
                                        MiscState.toggleSettings = true;
                                    }
                                }

                                HeaderButton {
                                    id: powerBtn

                                    glyph: "\uf011"
                                    // armed menu or hover lights it red
                                    property bool hot: root.showPowerPopup

                                    tint: hot || hovered ? "#ff5555" : Themes.muted
                                    border.color: hot ? Qt.rgba(0.95, 0.55, 0.66, 0.45) : hovered ? Qt.rgba(1, 0.33, 0.33, 0.45) : Qt.rgba(1, 1, 1, 0.08)

                                    onActivated: root.showPowerPopup = !root.showPowerPopup
                                }
                            }

                            // ═══ POWER ═══
                            PowerControls {
                                id: powerControls

                                Layout.fillWidth: true
                                Layout.bottomMargin: 8

                                showPowerPopup: root.showPowerPopup
                                timerPicker: root.timerPicker

                                onCloseRequested: root.showQsPopup = false
                                onTimerPicked: mode => root.timerPicker = mode
                            }

                            // ═══ NOW PLAYING ═══
                            NowPlaying {
                                id: nowPlayingCard

                                compactNowPlaying: root.compactNowPlaying
                                Layout.fillWidth: true
                                Layout.bottomMargin: 8
                                Layout.topMargin: 10
                            }

                            // ── breathing room when no media is playing ──
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                visible: !nowPlayingCard.visible
                            }

                            // ═══ VOLUME ═══
                            ClippingRectangle {
                                id: volumeCard

                                Layout.fillWidth: true
                                Layout.bottomMargin: 4
                                radius: 10
                                color: Themes.cardBg
                                border.width: 1
                                border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.25)
                                implicitHeight: volumeCol.implicitHeight + 16

                                ColumnLayout {
                                    id: volumeCol
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 8
                                    spacing: 5

                                    Brightness {
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 1
                                        visible: BrightnessState.available
                                        color: Themes.separator
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        RowLayout {
                                            // TODO: see redundancy
                                            Layout.fillWidth: true
                                            spacing: 20

                                            SinkName {
                                                visible: true
                                                node: PipewireState.outputSink
                                                fallback: "output"
                                                accent: Themes.accent
                                                displayName: PipewireState.outputDisplayName
                                            }
                                        }

                                        VolumeSlider {
                                            id: outVol
                                            node: PipewireState.outputSink
                                            glyph: "\uf028"
                                            glyphMuted: "\uf026"
                                            accent: Themes.accent
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3
                                        Layout.topMargin: 5
                                        // input sliders only make sense when an
                                        // input device is actually present
                                        visible: PipewireState.inputSink !== null

                                        SinkName {
                                            node: PipewireState.inputSink
                                            fallback: "input"
                                            accent: Themes.accent2
                                        }

                                        VolumeSlider {
                                            id: inVol
                                            node: PipewireState.inputSink
                                            glyph: "\uf130"
                                            glyphMuted: "\uf131"
                                            accent: Themes.accent2
                                        }
                                    }

                                    // ═══ PER-APPLICATION AUDIO — toggled by the cog ═══
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 1
                                        Layout.topMargin: 8
                                        visible: MiscState.showAppVolume
                                        color: Themes.separator
                                    }

                                    AppVolume {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 8
                                        visible: MiscState.showAppVolume
                                    }
                                }

                                // management cog — top-right corner of the card (same
                                // orientation/place as the now-playing button):
                                // left-click toggles the per-application volume list,
                                // right-click opens the full pipewire mixer (pwvucontrol)
                                Rectangle {
                                    id: pwBtn

                                    anchors {
                                        right: parent.right
                                        top: parent.top
                                        rightMargin: 8
                                        topMargin: 8
                                    }
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 5
                                    color: pwMouse.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.18) : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf013"
                                        color: MiscState.showAppVolume ? Themes.accent : pwMouse.containsMouse ? Themes.accent : Themes.muted
                                        font {
                                            pixelSize: 10
                                            family: "Symbols Nerd Font Mono"
                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: pwMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.showQsPopup = false;
                                                Quickshell.execDetached(["sh", "-c", "exec pwvucontrol 2>/dev/null || exec pwvucontrol"]);
                                            } else {
                                                MiscState.showAppVolume = !MiscState.showAppVolume;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
