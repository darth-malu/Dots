import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.themes

BarBlock {
    id: disk
    underline: false

    required property var host

    property bool showAllDisksPopup: false

    readonly property string diskUsage: ResourcesState.btrfsDevice
    readonly property color diskColor: {
        const match = diskUsage.match(/(\d+\.?\d*)/);
        if (match) {
            if (match[0] < 10) return "#a6e3a1";
            if (match[0] < 20) return "#f5c2e7";
            return "#89dceb";
        }
        return "#585b70";
    }

    readonly property var allDisksList: {
        var raw = ResourcesState.allDisks.trim();
        return raw.length > 0 ? raw.split("\n") : [];
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            showAllDisksPopup = !showAllDisksPopup;
    }

    content: BarText {
        id: textRow
        renderNative: true
        font {
            pixelSize: 12
            bold: true
            family: "ZedMono Nerd Font"
        }
        baseColor: disk.diskColor
        symbolText: ` ${disk.diskUsage}`
    }

    PopupWindow {
        id: allDisksPopup
        visible: disk.showAllDisksPopup
        grabFocus: true

        anchor.window: disk.host
        anchor.rect.x: {
            let g = disk.mapToGlobal(0, 0);
            return g.x + (disk.width / 2) - (width / 2);
        }
        anchor.rect.y: {
            let g = disk.mapToGlobal(0, 0);
            return g.y + disk.height + 4;
        }

        implicitWidth: 420
        implicitHeight: Math.min(allDisksCol.implicitHeight + 38, 400)

        Rectangle {
            anchors.fill: parent
            radius: 10
            clip: true
            color: "#1e1e2e"
            border.color: "#45475a"

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 34
                radius: 10
                color: Qt.rgba(0.49, 0.73, 0.44, 0.06)

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
                    text: "  All Mounts"
                    color: Themes.mprisTextColor
                    font { pixelSize: 12; bold: true; family: "Quicksand" }
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                    text: "size  used   %"
                    color: Themes.mprisVolumeColor
                    font { pixelSize: 9; family: "ZedMono Nerd Font"; letterSpacing: 1 }
                }
            }

            Rectangle {
                anchors { top: parent.top; topMargin: 34; left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14 }
                height: 1
                color: "#313244"
            }

            Flickable {
                anchors {
                    top: parent.top; topMargin: 42
                    left: parent.left; leftMargin: 14
                    right: parent.right; rightMargin: 14
                    bottom: parent.bottom; bottomMargin: 10
                }
                contentHeight: allDisksCol.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: allDisksCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: disk.allDisksList

                        RowLayout {
                            required property string modelData
                            spacing: 6

                            readonly property var parts: modelData.trim().split(/\s+/)
                            readonly property int pct: parts.length >= 5 ? parseInt(parts[4]) || 0 : 0

                            Text {
                                Layout.preferredWidth: 140
                                text: parent.parts[0] || ""
                                color: Themes.mprisTextColor
                                font { pixelSize: 10; family: "ZedMono Nerd Font" }
                                elide: Text.ElideRight
                                clip: true
                            }

                            Text {
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignRight
                                text: parent.parts[1] || ""
                                color: "#585b70"
                                font { pixelSize: 9; family: "ZedMono Nerd Font" }
                            }

                            Text {
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignRight
                                text: parent.parts[2] || ""
                                color: "#a6adc8"
                                font { pixelSize: 9; family: "ZedMono Nerd Font" }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 8
                                radius: 4
                                color: "#313244"

                                Rectangle {
                                    width: parent.width * Math.min(parent.parent.pct / 100, 1)
                                    height: parent.height
                                    radius: 4
                                    color: parent.parent.pct > 90 ? "#f38ba8" : parent.parent.pct > 70 ? "#f9e2af" : Themes.toxicGreen

                                    Behavior on width {
                                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                    }
                                }
                            }

                            Text {
                                Layout.preferredWidth: 32
                                horizontalAlignment: Text.AlignRight
                                text: `${parent.pct}%`
                                color: parent.parent.pct > 90 ? "#f38ba8" : "#a6adc8"
                                font { pixelSize: 9; family: "ZedMono Nerd Font"; bold: parent.pct > 90 }
                            }
                        }
                    }

                    Text {
                        text: "No mounts found"
                        color: "#585b70"
                        font { pixelSize: 10; family: "ZedMono Nerd Font" }
                        visible: disk.allDisksList.length === 0
                    }
                }
            }
        }
    }
}
