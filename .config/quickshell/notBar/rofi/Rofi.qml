import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick
import qs.services
import qs.themes

/* what this is?
+ This is a panel window with a list view inside it
+ it ingests:
  + model
  + delegate
  + ingests
  + iconUrl
  +app
*/

PanelWindow {
    id: launcher
    implicitWidth: RofiState.width
    implicitHeight: RofiState.height
    color: "transparent"
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // focus a Hyprland client reliably:
    // · close THIS panel first — while a layer surface holds exclusive
    //   keyboard focus, Hyprland refuses to apply client focus changes,
    //   so dispatching before closing silently did nothing
    // · Hyprland.dispatch uses the broken legacy wire format on 0.56+, so
    //   the actual focus goes through HyprlandService's /dispatch Lua socket
    // · wayland.activate() as last resort — its xdg-activation token is
    //   frequently ignored by Hyprland, hence the dispatcher preference
    function focusToplevel(tl) {
        if (!tl)
            return;
        RofiState.toggler();
        if (tl.address)
            HyprlandService.focusWindow(tl.address);
        else if (tl.wayland)
            tl.wayland.activate();
    }

    // BackgroundEffect.blurRegion: Region {
    //     item: launcher.contentItem
    // }

    property Item content
    required property var modelIngest
    required property Component delegateIngest

    property alias searchField: search.text

    // clipboard-manager hooks — emitted instead of the old raw-line copy so
    // binary/image entries survive a round-trip through `cliphist decode`
    signal clipChosen(string entry)
    signal clipDeleted(string entry)

    onVisibleChanged: {
        if (visible) {
            search.forceActiveFocus();
        }
    }

    WrapperRectangle {
        id: wrap
        color: Themes.launcherBg
        radius: 6
        anchors.fill: parent
        border {
            color: Themes.rofiBorder
            width: 1
        }

        child: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // ── header: mode glyph · search with placeholder · result count ──
            RowLayout {
                spacing: 10

                // nix logo fronts the app launcher; other modes keep glyphs
                IconImage {
                    visible: RofiState.toggleAppLauncher && !RofiState.toggleOpenWindows
                    source: Qt.resolvedUrl("../../svg/NixOS.svg")
                    implicitSize: 16
                    asynchronous: true
                }

                Text {
                    visible: !(RofiState.toggleAppLauncher && !RofiState.toggleOpenWindows)
                    text: RofiState.toggleOpenWindows ? "\uf2d0" : "\uf0ea"
                    color: Themes.rofiAccent
                    font {
                        pixelSize: 13
                        family: "Symbols Nerd Font Mono"
                    }
                }

                TextField {
                    id: search

                    Layout.fillWidth: true
                    enabled: true
                    hoverEnabled: true
                    maximumLength: 30
                    color: search.enabled ? Themes.windowTextColor : 'transparent'
                    selectByMouse: true
                    background: Rectangle {
                        color: 'transparent'
                        implicitHeight: 14
                        implicitWidth: 200
                        radius: 4
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier)) {
                            itemLauncher.currentIndex = itemLauncher.currentIndex > 0 ? itemLauncher.currentIndex - 1 : itemLauncher.count - 1;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier)) {
                            itemLauncher.currentIndex = itemLauncher.currentIndex < itemLauncher.count - 1 ? itemLauncher.currentIndex + 1 : 0;
                            event.accepted = true;
                        } else if (event.key == Qt.Key_Return && event.modifiers & Qt.ControlModifier) {
                            //DELETE STUFF HERE
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            let current = itemLauncher.currentItem;
                            if (current) {
                                if (RofiState.toggleOpenWindows)
                                    // Current Item is a Window(toplevel) —
                                    // focusToplevel closes the panel itself
                                    focusToplevel(current.modelData);
                                else if (RofiState.toggleAppLauncher)
                                    // Current Items is a DesktopEntry.
                                    current.modelData.execute();
                                else if (RofiState.toggleClipHist) {
                                    // Current Item is a raw cliphist list line ("id\tpreview")
                                    launcher.clipChosen(current.modelData);
                                }
                            // openWindows path closes the panel inside
                            // focusToplevel — everything else toggles here
                            if (!RofiState.toggleOpenWindows)
                                RofiState.toggler();
                            search.text = "";
                                event.accepted = true;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete && RofiState.toggleClipHist) {
                            // remove the selected entry from the history
                            let current = itemLauncher.currentItem;
                            if (current) {
                                launcher.clipDeleted(current.modelData);
                                event.accepted = true;
                            }
                        } else if (event.key === Qt.Key_Escape) {
                            RofiState.toggler();
                            search.text = "";
                            event.accepted = true;
                            // itemLauncher.positionViewAtBeginning();
                            itemLauncher.currentIndex = 0;
                        }
                    }
                }

                Text {
                    visible: itemLauncher.count > 0
                    text: itemLauncher.count
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.4)
                    font {
                        pixelSize: 10
                        family: "ZedMono Nerd Font"
                    }
                }
            }

            function copier() {
            }

            ListView {
                id: itemLauncher
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                highlightMoveDuration: 150
                // highlightRangeMode: ListView.StrictlyEnforceRange
                keyNavigationWraps: false
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                signal accepted(var item)

                // required property var model

                property var inputText

                // property alias modelIngest: root.model

                // TODO outsrc this
                model: launcher.modelIngest

                highlight: HighlightItem {}

                delegate: launcher.delegateIngest

                function activateCurrent() {
                    let current = currentItem;
                    if (!current)
                        return;
                    const wasWindows = RofiState.toggleOpenWindows;
                    if (wasWindows)
                        focusToplevel(current.modelData); // closes the panel itself
                    else {
                        if (RofiState.toggleAppLauncher)
                            current.modelData.execute();
                        else if (RofiState.toggleClipHist)
                            launcher.clipChosen(current.modelData);
                        RofiState.toggler();
                    }
                    search.text = "";
                }

                ScrollBar.vertical: ScrollBar {
                    policy: itemLauncher.contentHeight > itemLauncher.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                // quiet empty state instead of a blank box
                Text {
                    anchors.centerIn: parent
                    visible: itemLauncher.count === 0
                    text: RofiState.toggleClipHist ? "clipboard is empty" : "no matches"
                    color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                    font {
                        pixelSize: 11
                        letterSpacing: 1
                        family: "ZedMono Nerd Font"
                    }
                }
            }

        }
    }
}
