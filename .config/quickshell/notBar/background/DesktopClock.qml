pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
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
        visible: WallpaperService.enabled && WallpaperService.desktopClock

        exclusionMode: ExclusionMode.Ignore
        // Bottom layer: renders above the wallpaper (Background) regardless
        // of surface stacking order, but stays behind the bar and windows.
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell-clock"

        color: "transparent"

        // empty click mask so the fullscreen clock never swallows input
        // (same trick as Activate.qml — sticky surfaces don't grab clicks)
        mask: Region {}

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        Item {
            anchors.fill: parent

            // positioned bottom-right with margins
            ColumnLayout {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 40
                spacing: 4

                // time
                Text {
                    id: clockTime
                    Layout.alignment: Qt.AlignRight
                    color: Themes.desktopText
                    font { pixelSize: 64; family: "ZedMono Nerd Font"; bold: true }
                    style: Text.Outline
                    styleColor: Themes.desktopOutline

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
                        onTriggered: clockTime.updateTime()
                    }
                }

                // date
                Text {
                    id: clockDate
                    Layout.alignment: Qt.AlignRight
                    color: Themes.desktopMuted
                    font { pixelSize: 16; family: "Quicksand"; bold: true; letterSpacing: 1 }
                    style: Text.Outline
                    styleColor: Themes.desktopOutline

                    function updateDate() {
                        var now = new Date();
                        var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
                        var months = ["January", "February", "March", "April", "May", "June",
                            "July", "August", "September", "October", "November", "December"];
                        text = days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate();
                    }

                    Component.onCompleted: updateDate()

                    Timer {
                        interval: 60000
                        repeat: true
                        running: true
                        onTriggered: clockDate.updateDate()
                    }
                }
            }
        }
    }
}
