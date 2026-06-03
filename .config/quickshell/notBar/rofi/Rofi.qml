import Quickshell
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick
import qs.services

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

    property Item content

    // WlrLayershell.keyboardFocus: WlrLayerShell.OnDemand
    // WlrLayershell.layer: WlrLayer.Overlay
    required property var modelIngest
    required property Component delegateIngest

    property alias searchField: search.text

    onVisibleChanged: {
        if (visible) {
            search.forceActiveFocus();
        }
    }

    WrapperRectangle {
        id: wrap
        color: Qt.rgba(12 / 255, 44 / 255, 44 / 255, 0.9) // "#282a36" //"#1e1e2e"
        radius: 6
        anchors.fill: parent
        border {
            color: Qt.rgba(63 / 255, 167 / 255, 197 / 255, 0.42)
            width: 1
        }

        child: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            RowLayout {
                spacing: 20

                Text {
                    text: "  "
                    color: Qt.rgba(63 / 255, 167 / 255, 197 / 255, 0.82)
                    horizontalAlignment: Qt.AlignRight
                }

                TextField {
                    id: search

                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    enabled: true
                    hoverEnabled: true
                    maximumLength: 30
                    color: search.enabled ? Qt.rgba(171 / 255, 141 / 255, 237 / 255, 1) : 'transparent'
                    background: Rectangle {
                        color: 'transparent'
                        implicitHeight: 10
                        implicitWidth: 200
                        radius: 4
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier)) {
                            itemLauncher.decrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier)) {
                            itemLauncher.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key == Qt.ControlModifier && Qt.Key_Return) {
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
                                    // Current Items is a String of Number\tString.
                                    Quickshell.clipboardText = current.modelData;
                                    // Quickshell.execDetached(["bash", "-c", "cliphist decode <<EOF | wl-copy\n" + current.modelData + "\nEOF"]);
                                    // Quickshell.execDetached(["notify-send", `${Quickshell.clipboardText}`]);
                                }
                                RofiState.toggler();
                                search.text = "";
                                event.accepted = true;
                            }
                            event.accepted = true;
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
                keyNavigationWraps: true

                signal accepted(var item)

                // required property var model

                property var inputText

                // property alias modelIngest: root.model

                // TODO outsrc this
                model: launcher.modelIngest

                highlight: HighlightItem {}

                delegate: launcher.delegateIngest
            }
        }
    }
}
