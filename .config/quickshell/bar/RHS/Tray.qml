import QtQuick.Layouts
import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell

RowLayout {
    id: trayRow

    spacing: 6

    readonly property int trayCount: _repeater.count
    readonly property bool singleItem: _repeater.count <= 1

    // horizontal pill padding lives inside the content row so
    // the slab's implicit width always covers it
    Item {
        visible: !_repeater.singleItem
        Layout.preferredWidth: 1
    }

    Repeater {
        id: _repeater
        model: SystemTray.items

        delegate: Rectangle {
            id: delegate

            required property SystemTrayItem modelData

            readonly property var item: modelData
            readonly property bool hasMenu: item?.hasMenu ?? false

            // menu only opens while this flag is armed — a stale
            // QsMenuAnchor grabbing focus was closing it instantly
            property bool menuArmed: false

            onHasMenuChanged: if (!hasMenu)
                menuArmed = false

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 13
            implicitHeight: 13
            color: "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 110
                }
            }

            // gentle squish on press — tactile without being noisy
            scale: delegateMa.pressed ? 0.86 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }
            }

            IconImage {
                anchors.centerIn: parent
                source: parent.item.icon
                implicitSize: 13
                asynchronous: true
                opacity: delegateMa.containsMouse || delegateMa.pressed ? 1 : 0.88

                Behavior on opacity {
                    NumberAnimation {
                        duration: 110
                    }
                }
            }

            // ToolTip.visible: delegateMa.containsMouse && !menuAnchor.visible && delegate.tipText.length > 0
            // ToolTip.delay: 450
            // ToolTip.text: delegate.tipText

            MouseArea {
                id: delegateMa

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: event => {
                    if (event.button == Qt.LeftButton) {
                        try {
                            delegate.item.activate();
                        } catch (e) {}
                    } else if (event.button == Qt.RightButton) {
                        if (delegate.hasMenu) {
                            delegate.menuArmed = true;
                            menuAnchor.open();
                        } else {
                            try {
                                delegate.item.activate();
                            } catch (e) {}
                        }
                    } else if (event.button == Qt.MiddleButton) {
                        try {
                            delegate.item.secondaryActivate();
                        } catch (e) {}
                    }
                }
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: delegate.menuArmed ? delegate.item.menu : null

                anchor.window: delegate.QsWindow.window
                // NOTE: binds to the  systemtrayItem that called the menu
                anchor.adjustment: PopupAdjustment.Flip

                anchor.onAnchoring: {
                    const window = delegate.QsWindow.window;
                    const widgetRect = window.contentItem.mapFromItem(delegate, 0, delegate.height, delegate.width, 0);

                    menuAnchor.anchor.rect = widgetRect;
                }
            }
        }
    }

    // horizontal pill padding lives inside the content row so
    // the slab's implicit width always covers it
    Item {
        visible: !_repeater.singleItem
        Layout.preferredWidth: 1
    }
}
