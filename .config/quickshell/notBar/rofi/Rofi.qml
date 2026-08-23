import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
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

            RowLayout {
                spacing: 20

                Text {
                    text: " "
                    color: Themes.rofiAccent
                    horizontalAlignment: Qt.AlignRight
                }

                TextField {
                    id: search

                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    enabled: true
                    hoverEnabled: true
                    maximumLength: 30
                    color: search.enabled ? Themes.windowTextColor : 'transparent'
                    background: Rectangle {
                        color: 'transparent'
                        implicitHeight: 10
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
                                    // Current Item is a Window(toplevel)
                                    current.modelData.wayland.activate();
                                else if (RofiState.toggleAppLauncher)
                                    // Current Items is a DesktopEntry.
                                    current.modelData.execute();
                                else if (RofiState.toggleClipHist) {
                                    // Current Item is a raw cliphist list line ("id\tpreview")
                                    launcher.clipChosen(current.modelData);
                                }
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
            }

            function copier() {
            }

            ListView {
                id: itemLauncher
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
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
                    if (current) {
                        if (RofiState.toggleOpenWindows)
                            current.modelData.wayland.activate();
                        else if (RofiState.toggleAppLauncher)
                            current.modelData.execute();
                        else if (RofiState.toggleClipHist)
                            launcher.clipChosen(current.modelData);
                        RofiState.toggler();
                        search.text = "";
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: itemLauncher.contentHeight > itemLauncher.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }
            }
        }
    }
}
