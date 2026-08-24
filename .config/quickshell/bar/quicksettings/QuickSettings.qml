import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
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
        implicitWidth: 310
        implicitHeight: qsContent.implicitHeight + 16

        // drop shadow drawn from a proxy silhouette so the real card never
        // passes through the effect (stays pixel-crisp and fully interactive)
        MultiEffect {
            anchors.fill: parent
            source: shadowProxy
            shadowEnabled: true
            shadowBlur: 0.85
            shadowColor: Qt.rgba(0, 0, 0, 0.6)
            shadowVerticalOffset: 5
        }

        Rectangle {
            id: shadowProxy
            anchors.fill: parent
            anchors.margins: 8
            radius: 12
            visible: false
            color: MiscState.popupCardBg
        }

        Rectangle {
            id: qsCard
            anchors.fill: parent
            anchors.margins: 8
            radius: 12
            color: MiscState.popupCardBg

            Shortcut {
                sequence: "Escape"
                onActivated: root.showQsPopup = false
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.showQsPopup = false
                z: -1
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
                        Layout.bottomMargin: 8

                        content: RowLayout {
                            id: headerBeforeCards
                            Layout.fillWidth: true
                            spacing: 10

                            // avatar — click to choose a new one
                            ClippingRectangle {
                                id: avatarBox
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: height / 2
                                color: avatarMa.containsMouse ? Qt.rgba(0.74, 0.58, 0.98, 0.18) : "#343746"
                                // hairline ring keeps the circle crisp against the card
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
                                    shadowHorizontalOffset: 0
                                    shadowVerticalOffset: 0
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

                            // identity block — optically centred against the
                            // 40px avatar, hostname over dimmed uptime
                            ColumnLayout {
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true

                                StyledText {
                                    text: root.hostName
                                    horizontalAlignment: Text.AlignLeft
                                    font {
                                        pixelSize: 13
                                        family: "Quicksand"
                                        bold: true
                                        letterSpacing: 0.3
                                    }
                                    color: "#f8f8f2"
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 180
                                }

                                RowLayout {
                                    spacing: 4

                                    Text {
                                        text: "\uf017"
                                        color: "#6272a4"
                                        font {
                                            pixelSize: 9
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    StyledText {
                                        text: ResourcesState.uptimeText
                                        visible: text.length > 0
                                        horizontalAlignment: Text.AlignLeft
                                        font {
                                            pixelSize: 10
                                            family: "ZedMono Nerd Font"
                                        }
                                        color: "#b8bfcb"
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // gap between the identity block and the control icons
                            Item {
                                Layout.fillWidth: true
                            }

                            // utility cluster — power stays put; hovering it
                            // slides the rest of the row out to its left
                            Item {
                                id: ctrlCluster

                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignRight
                                implicitWidth: revealGroup.width + 10 + 32
                                width: ctrlCluster.revealed ? implicitWidth : 32
                                clip: true

                                // stays open while a popup card is up so the row doesn't slam shut
                                readonly property bool revealed: clusterHover.hovered || root.showPowerPopup

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                HoverHandler {
                                    id: clusterHover
                                }

                                // the hover-revealed buttons — fade + slide as one unit
                                Item {
                                    id: revealGroup

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: ctrlCluster.revealed ? hiddenRow.implicitWidth : 0
                                    height: 32
                                    clip: true
                                    opacity: ctrlCluster.revealed ? 1 : 0

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }

                                    RowLayout {
                                        id: hiddenRow

                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Rectangle {
                                            id: controls

                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 6
                                            color: caffeineMouse.containsMouse ? Qt.rgba(0.98, 0.70, 0.53, 0.15) : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: CaffeineService.enabled ? "\uf0f4" : "󰾪"
                                                color: CaffeineService.enabled ? "#ffb86c" : "#6272a4"
                                                font {
                                                    pixelSize: 16
                                                    family: "Symbols Nerd Font Mono"
                                                }
                                            }

                                            MouseArea {
                                                id: caffeineMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: CaffeineService.toggle()
                                            }
                                        }

                                        Rectangle {

                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 6
                                            color: settingsBtnMouse.containsMouse ? Qt.rgba(0.54, 0.57, 0.96, 0.15) : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: ""
                                                color: "#bd93f9"
                                                font {
                                                    pixelSize: 16
                                                    family: "Symbols Nerd Font Mono"
                                                }
                                            }

                                            MouseArea {
                                                id: settingsBtnMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.showQsPopup = false;
                                                    MiscState.toggleSettings = true;
                                                }
                                            }
                                        }
                                    }
                                }

                                // power — always visible on the right edge
                                Rectangle {

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32
                                    height: 32
                                    radius: 6
                                    color: powerBtnMouse.containsMouse ? Qt.rgba(0.95, 0.55, 0.66, 0.15) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: root.showPowerPopup ? "#ff5555" : "#6272a4"
                                        font {
                                            pixelSize: 16
                                            family: "Symbols Nerd Font Mono"
                                        }
                                    }

                                    MouseArea {
                                        id: powerBtnMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showPowerPopup = !root.showPowerPopup
                                    }
                                }
                            }
                        }
                    }

                    // ═══ POWER ═══
                    PowerControls {
                        id: powerControls

                        showPowerPopup: root.showPowerPopup
                        timerPicker: root.timerPicker

                        onCloseRequested: root.showQsPopup = false
                        onTimerPicked: mode => root.timerPicker = mode
                    }

                    // dark deck behind the media + audio cards — the cards
                    // pop out of it instead of floating loose on the card bg
                    Rectangle {
                        z: -1
                        radius: 14
                        color: MiscState.popupSolidBg ? "#191a24" : Qt.rgba(0.075, 0.078, 0.106, 0.72)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.05)

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: nowPlayingCard.top
                            bottom: volumeCard.bottom
                            topMargin: -10
                            bottomMargin: 2
                            leftMargin: -10
                            rightMargin: -10
                        }

                        Behavior on color {
                            ColorAnimation { duration: 160 }
                        }
                    }

                    // ═══ NOW PLAYING ═══
                    NowPlaying {
                        id: nowPlayingCard

                        compactNowPlaying: root.compactNowPlaying
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                    }
                    }

                    // ═══ VOLUME ═══
                ClippingRectangle {
                    id: volumeCard

                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
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
            }
        }
    }


    component SinkName: RowLayout {
        required property PwNode node
        required property string fallback
        required property color accent
        property string displayName

        Layout.fillWidth: true
        spacing: 6

        Text {
            text: {
                if (parent.displayName && parent.displayName.length > 0)
                    return parent.displayName;
                const d = parent.node?.description;
                return d && d.length > 0 ? d : parent.fallback;
            }
            color: parent.accent
            elide: Text.ElideRight
            font {
                pixelSize: 10
                bold: true
                family: "Quicksand"
                letterSpacing: 1
            }
            Layout.fillWidth: true
        }

        Text {
            visible: parent.node === null
            text: "unavailable"
            color: "#6272a4"
            font {
                pixelSize: 9
                family: "ZedMono Nerd Font"
            }
        }
    }
}
