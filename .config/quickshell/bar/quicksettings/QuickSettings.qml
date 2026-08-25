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

BarBlock {
    id: root

    required property var host

    property string hostName: QuickState.hostName

    property bool playerListOpen: false // reserved for a future chooser popup
    property bool showQsPopup: false
    property bool showPowerPopup: false
    // 0 = hidden, 1 = reboot presets, 2 = shutdown presets
    property int timerPicker: 0
    property bool compactNowPlaying: true
    property bool shuffleOn: false
    property bool loopOn: false

    // ── player chooser — hidden until the bottom-left region is hovered,
    // which reveals a small launcher button; clicking it expands the chip
    // strip (wheel steps through players, click pins) ──

    // ── volume OSD ──
    onLeftClicked: {
        root.showQsPopup = !root.showQsPopup;
    }

    onShowQsPopupChanged: {
        MiscState.qsOpen = showQsPopup;
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

    PopupWindow {
        id: quickSettingsPopup
        visible: root.showQsPopup
        grabFocus: true
        // always transparent — the card below paints its own opaque
        // background; an opaque window backdrop would square off the
        // corners around the rounded card and shadow (border artifacts)
        color: "transparent"

        anchor.window: root.host
        anchor.rect.x: {
            let g = root.mapToGlobal(0, 0);
            return g.x + (root.width / 2) - (width / 2);
        }
        anchor.rect.y: 33

        // rigid footprint — height always hugs the full content, never scrolls
        implicitWidth: 300
        // top inset 4 (content margins) + 3 below the last row
        implicitHeight: qsContent.implicitHeight + 7

        // same treatment as every other popup: one full-bleed rounded card
        // with a hairline ring — no shadow effect, whose blur used to clip
        // square-ish at the window edges
        Rectangle {
            id: qsCard
            anchors.fill: parent
            radius: 12
            color: MiscState.popupCardBg
            border.width: 1
            border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)

            Shortcut {
                sequence: "Escape"
                onActivated: root.showQsPopup = false
            }

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
                                visible: false
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: height / 2
                                color: avatarMa.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.18) : "#343746"
                                border.width: 1
                                border.color: avatarMa.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.55) : Qt.rgba(1, 1, 1, 0.14)

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 140
                                    }
                                }

                                // halo of light on hover
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowColor: Qt.rgba(0.741, 0.576, 0.976, 1)
                                    shadowBlur: 0.85
                                    autoPaddingEnabled: true
                                    shadowOpacity: avatarMa.containsMouse ? 0.95 : 0

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
                                    color: "#6272a4"
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

                            Item {
                                Layout.fillWidth: true
                            }

                            // square icon buttons — one component, one look
                            component HeaderButton: Rectangle {
                                id: hbtn

                                property string glyph
                                property color tint: "#bd93f9"
                                readonly property alias hovered: hbtnMa.containsMouse

                                signal activated()

                                width: 30
                                height: 30
                                radius: 9
                                color: hbtnMa.containsMouse ? Qt.rgba(hbtn.tint.r, hbtn.tint.g, hbtn.tint.b, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: hbtnMa.containsMouse ? Qt.rgba(hbtn.tint.r, hbtn.tint.g, hbtn.tint.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                scale: hbtnMa.pressed ? 0.92 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 80
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: hbtn.glyph
                                    color: hbtnMa.containsMouse ? Qt.lighter(hbtn.tint, 1.25) : "#b8bfcb"
                                    font {
                                        pixelSize: 14
                                        family: "Symbols Nerd Font Mono"
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                }

                                MouseArea {
                                    id: hbtnMa

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: hbtn.activated()
                                }
                            }

                            HeaderButton {
                                glyph: "\uf0f4"
                                tint: CaffeineService.enabled ? "#ffb86c" : "#6272a4"

                                onActivated: CaffeineService.toggle()
                            }

                            HeaderButton {
                                glyph: "\uf013"
                                tint: "#bd93f9"

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

                                tint: hot || hovered ? "#ff5555" : "#6272a4"
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
                        }

                        // ═══ VOLUME ═══
                        ClippingRectangle {
                            id: volumeCard

                            Layout.fillWidth: true
                            Layout.bottomMargin: 4
                            radius: 10
                            color: "#21222c"
                            border.width: 1
                            border.color: Qt.rgba(0.74, 0.58, 0.98, 0.25)
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
                                    color: "#343746"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        SinkName {
                                            node: PipewireState.outputSink
                                            fallback: "output"
                                            accent: "#bd93f9"
                                            displayName: PipewireState.outputDisplayName
                                        }

                                        Rectangle {
                                            id: pwBtn

                                            // pw management shortcut (hyprpwcenter)
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            radius: 5
                                            color: pwMouse.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.18) : "transparent"

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 120
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf013"
                                                color: pwMouse.containsMouse ? "#bd93f9" : "#6272a4"
                                                font {
                                                    pixelSize: 10
                                                    family: "Symbols Nerd Font Mono"
                                                }
                                            }

                                            MouseArea {
                                                id: pwMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.showQsPopup = false;
                                                    Quickshell.execDetached(["sh", "-c", "exec hyprpwcenter 2>/dev/null || exec pwvucontrol"]);
                                                }
                                            }
                                        }
                                    }

                                    VolumeSlider {
                                        id: outVol
                                        node: PipewireState.outputSink
                                        glyph: "\uf028"
                                        glyphMuted: "\uf026"
                                        accent: "#bd93f9"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    SinkName {
                                        node: PipewireState.inputSink
                                        fallback: "input"
                                        accent: "#8be9fd"
                                    }

                                    VolumeSlider {
                                        id: inVol
                                        node: PipewireState.inputSink
                                        glyph: "\uf130"
                                        glyphMuted: "\uf131"
                                        accent: "#8be9fd"
                                    }
                                }
                            }
                        }

                        // ── footer · session uptime ──
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: ResourcesState.uptimeText.length > 0 ? ResourcesState.uptimeText : "…"
                            color: "#6272a4"
                            font {
                                pixelSize: 9
                                bold: true
                                family: "ZedMono Nerd Font"
                            }
                        }
                    }
                }
            }
        }
    }
}
