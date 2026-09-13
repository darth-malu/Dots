pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.themes

// Desktop quotes slideshow — a quiet rotating deck of factoids from computing
// legends, rendered like the desktop clock (Bottom layer, above wallpaper,
// below the bar). Fades softly between quotes on the QuotesState timer.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData
        visible: WallpaperService.enabled && WallpaperService.quotesEnabled

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell-quotes"

        color: "transparent"

        // empty click mask so the surface never swallows input (same trick as
        // DesktopClock / Activate.qml)
        mask: Region {}

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        Item {
            anchors.fill: parent

            // crossfade host — holds the current quote, swapped mid-animation
            // so the fade-out shows the old text and fade-in the new one
            Item {
                id: quoteWrap
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 40
                anchors.rightMargin: 40
                anchors.bottomMargin: 48

                property var held: QuotesState.current

                // soft glass chip — the quote sits on a quiet slab so it stays
                // readable over any wallpaper (the heavy text outlines are gone).
                // Off by default (QuotesState.showBg) so the text floats bare.
                Rectangle {
                    id: quoteCard
                    visible: QuotesState.showBg
                    anchors.fill: quoteCol
                    radius: 14
                    color: Qt.rgba(0.02, 0.03, 0.05, 0.55)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                }

                ColumnLayout {
                    id: quoteCol
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: Math.min(parent.width - 160, 660)
                    spacing: 10

                    Text {
                        id: quoteBody
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        text: quoteWrap.held.q
                        color: Themes.fg
                        font { pixelSize: 15; family: QuotesState.quoteFont; weight: Font.Normal; letterSpacing: 0.25 }
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 12
                            Layout.preferredHeight: 1
                            color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.6)
                        }

                        Text {
                            id: quoteAuthor
                            text: quoteWrap.held.a.toUpperCase()
                            color: Themes.dim
                            font { pixelSize: 9; family: QuotesState.authorFont; bold: true; letterSpacing: 1.8 }
                        }

                        Rectangle {
                            Layout.preferredWidth: 12
                            Layout.preferredHeight: 1
                            color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.6)
                        }
                    }
                }
            }

            // new slide → fade out, swap text, fade in
            Connections {
                target: QuotesState
                function onIndexChanged() {
                    slideAnim.restart();
                }
            }

            SequentialAnimation {
                id: slideAnim
                running: false // started via onIndexChanged
                PropertyAnimation {
                    target: quoteWrap
                    property: "opacity"
                    to: 0
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
                ScriptAction { script: quoteWrap.held = QuotesState.current }
                PropertyAnimation {
                    target: quoteWrap
                    property: "opacity"
                    to: 1
                    duration: 400
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
}