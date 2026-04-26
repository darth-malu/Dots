pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.customItems
import qs.themes

Loader {
    id: mprisLoader

    active: MprisState.mprisVisible

    visible: active

    // onVisibleChanged: {
    //     MprisState.mprisVisible = !MprisState.mprisVisible;
    // }

    required property var host

    sourceComponent: WrapperMouseArea {
        id: mprisRoot

        hoverEnabled: true

        acceptedButtons: Qt.RightButton | Qt.LeftButton | Qt.MiddleButton | Qt.ForwardButton | Qt.BackButton

        property bool showVolume: false

        property bool showPlaying: MprisState.player?.isPlaying

        property bool showPopup: false

        LazyLoader {
            loading: true

            PopupWindow {
                id: popup

                anchor.window: mprisLoader.host
                anchor.rect.x: mprisLoader.host.width / 2 - width / 2
                anchor.rect.y: 35
                visible: mprisRoot.showPopup
                color: 'transparent'
                implicitWidth: Math.min(600, mprisPopupRectangle.implicitWidth + 10)
                implicitHeight: mprisPopupRectangle.implicitHeight + 20

                WrapperRectangle {
                    id: mprisPopupRectangle
                    radius: 6
                    anchors.fill: parent
                    // implicitWidth: playersContainer.implicitWidth
                    // implicitWidth: 150

                    color: Qt.rgba(0.1, 0.04, 0.18, 0.7) // The "Glass" Color - Dark with a purple tint and transparency
                    border.width: 1
                    border.color: '#A020F0'

                    MprisPopup {}
                }
            }
        }

        Timer {
            id: hideVolumeTimer
            interval: 1000
            repeat: false
            running: false
            onTriggered: mprisRoot.showVolume = false
        }

        onExited: {
            hideVolumeTimer.restart();
        }

        onClicked: mouse => {
            mouse.accepted = true; // Prevent background click
            if (mouse.button == Qt.LeftButton)
                MprisState.player?.togglePlaying();
            else if (mouse.button == Qt.RightButton)
                MprisState.player?.next();
            else if (mouse.button == Qt.ForwardButton) {
                if (MprisState.player?.identity === "Music Player Daemon")
                    Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "nc"]);
                else {
                    MprisState.player?.raise();
                }
            } else if (mouse.button == Qt.MiddleButton)
                showPopup = !showPopup;
        }

        onWheel: event => {
            if (!MprisState.player?.isPlaying)
                return;

            if (MprisState.player?.volumeSupported) {
                let vol = MprisState.player.volume * 100; // Convert current volume (0.0–1.0) to percent

                vol += event.angleDelta.y > 0 ? 4 : -4; // Scroll up increases, down decreases

                vol = Math.max(0, Math.min(vol, 100)); // Clamp between 0% and 100%

                MprisState.player.volume = vol / 100; // Apply back to player

                mprisRoot.showVolume = true;
            }
        }

        RowLayout {
            visible: mprisRoot.showPlaying

            ClippingWrapperRectangle {
                id: albumArt
                visible: MprisState.mprisArtVisible
                radius: height / 2
                implicitWidth: mprisLoader.host.height
                implicitHeight: mprisLoader.host.height
                color: 'transparent'
                Image {
                    id: albumArtImage
                    anchors.fill: parent
                    source: MprisState.player.trackArtUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }

            BarText {
                id: title
                renderNative: true
                text: {
                    let strLength = 50;
                    var str = MprisState.player?.trackTitle;
                    return str.length > strLength ? str.slice(0, strLength) + '..' : str;
                }
                color: Themes.mprisTextColor
                font: Themes.quicksand_medium
            }

            BarText {
                id: volumePlayer
                visible: mprisRoot.showVolume
                text: Math.round(MprisState.player?.volume * 100) ?? ""
                font: title.font
                color: Themes.mprisVolumeColor
            }
        }
    }
}
