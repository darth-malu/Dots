pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.themes

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData
        visible: WallpaperService.enabled

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-bg"

        color: "transparent"

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        // wallpaper image with fade transition
        Item {
            anchors.fill: parent

            Loader {
                id: wallpaperLoader
                anchors.fill: parent
                active: WallpaperService.current.length > 0

                sourceComponent: Image {
                    id: wallpaperImg
                    source: WallpaperService.current
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize: {
                        const dpr = win.screen?.devicePixelRatio ?? 1;
                        return Qt.size(win.width * dpr, win.height * dpr);
                    }

                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutQuad }
                    }
                }
            }

            // fallback when no wallpaper is set
            Rectangle {
                anchors.fill: parent
                visible: WallpaperService.current.length === 0
                color: Themes.panelBg
            }
        }

        // scroll to cycle wallpapers
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                if (wheel.angleDelta.y > 0)
                    WallpaperService.nextWallpaper();
                else if (wheel.angleDelta.y < 0)
                    WallpaperService.prevWallpaper();
            }
        }

        // caelestia-style screen frame — a rounded accent outline around the
        // whole viewport, hugging the screen edges (like a window border).
        // The bar overlays the top edge; the frame's rounded corners carry
        // the outline around the bar's base, so it reads as one continuous
        // frame around the desktop.
        Rectangle {
            visible: BarState.frameOn
            anchors.fill: parent
            anchors.margins: 2
            radius: 12
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.55)
            z: 10
        }
    }
}
