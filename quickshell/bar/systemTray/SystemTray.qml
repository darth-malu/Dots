pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.customItems
import qs.themes
import qs.bar
import qs.services

RowLayout {
    id: root

    anchors.verticalCenter: parent.verticalCenter

    Loader {
        visible: active
        asynchronous: true
        active: MiscState.toggleSysTray

        Layout.fillHeight: true // ENSURE THE LOADER TAKES UP SPACE- enable clicking inside it 😀
        Layout.topMargin: 4
        Layout.bottomMargin: 3

        sourceComponent: sysBlock
    }

    Component {
        id: sysBlock
        BarBlock {
            implicitWidth: tray.implicitWidth
            implicitHeight: tray.implicitHeight

            color: Qt.rgba(1, 1, 1, 0.19)

            RowLayout {
                id: tray
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 2

                Repeater {
                    model: SystemTray.items

                    delegate: MouseArea {
                        id: delegate

                        required property SystemTrayItem modelData

                        property alias item: delegate.modelData

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        implicitWidth: icon.implicitWidth + 4

                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                        hoverEnabled: true

                        onClicked: event => {
                            if (event.button == Qt.LeftButton) {
                                item.activate();
                            } else if (event.button == Qt.RightButton) {
                                menuAnchor.open();
                            } else if (event.button == Qt.MiddleButton) {
                                item.secondaryActivate();
                            }
                        }

                        IconImage {
                            id: icon
                            // anchors.verticalCenter: parent.verticalCenter
                            anchors.centerIn: parent
                            // Layout.alignment: Qt.AlignCenter
                            source: modelData.icon
                            implicitSize: 12
                            asynchronous: true
                        }

                        QsMenuAnchor {
                            // FIXME: Make The flickering stop
                            id: menuAnchor
                            menu: modelData.menu

                            anchor.window: delegate.QsWindow.window // Use root.QsWindow.window direct?
                            anchor.adjustment: PopupAdjustment.Flip

                            anchor.onAnchoring: {
                                const window = delegate.QsWindow.window;
                                const widgetRect = window.contentItem.mapFromItem(delegate, 0, delegate.height, delegate.width, delegate.height);

                                menuAnchor.anchor.rect = widgetRect;
                            }
                        }

                        // TODO make tooltip
                        /* Tooltip { */
                        /*   relativeItem: delegate.containsMouse ? delegate : null */

                        /*   Label { */
                        /*     text: delegate.item.tooltipTitle || delegate.item.id */
                        /*   } */
                        /* } */
                    }
                }
            }
        }
    }

    Caffeine {
        visible: MiscState.toggleSysTray
        pointSize: icon.implicitSize
    }

    BarBlock {
        id: toggleSystemTray
        implicitHeight: 10
        implicitWidth: 10
        anchors.verticalCenter: parent.verticalCenter
        content: BarText {
            paddingg: 0
            pointSize: 12
            // Logic to Toggle to in or out
            text: if (MiscState.toggleSysTray)
                ''
            else
                ''
            color: !MiscState.toggleSysTray ? Themes.mprisIndicatorColor : Qt.rgba(1, 1, 1, 0.35)
        }
        hoveredBg: false
        onClicked: MiscState.toggleSysTray = !MiscState.toggleSysTray
    }
}
