import QtQuick.Layouts
import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell
import qs.services
import qs.themes

// A single menu row. Renders the entry, and — when it has children — manages a
// nested custom-styled PopupWindow so every level of the menu shares the same
// themed background, radius, border and hover highlight.

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

            property bool menuOpen: false

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
                            delegate.menuOpen = true;
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

            // ── custom-styled root menu popup ──────────────────────────
            PopupWindow {
                id: menuPopup
                visible: delegate.menuOpen
                grabFocus: true
                color: "transparent"

                anchor.window: delegate.QsWindow.window
                anchor.rect.x: {
                    const r = delegate.QsWindow.window.contentItem.mapFromItem(delegate, 0, 0, delegate.width, delegate.height);
                    return r.x;
                }
                anchor.rect.y: {
                    const r = delegate.QsWindow.window.contentItem.mapFromItem(delegate, 0, 0, delegate.width, delegate.height);
                    return r.y + r.height;
                }

                readonly property real pad: 6
                readonly property real menuRadius: Themes.boxyRadius + 6

                implicitWidth: 200
                implicitHeight: menuColumn.implicitHeight + menuPopup.pad * 2

                onVisibleChanged: if (!visible)
                    delegate.menuOpen = false

                Keys.onEscapePressed: delegate.menuOpen = false

                QsMenuOpener {
                    id: menuOpener
                    menu: delegate.menuOpen ? delegate.item.menu : null
                }

                Rectangle {
                    id: menuSurface
                    anchors.fill: parent
                    radius: menuPopup.menuRadius
                    color: MiscState.popupCardBg
                    border.width: 1
                    border.color: Qt.rgba(0.74, 0.58, 0.98, 0.3)
                    clip: true

                    Column {
                        id: menuColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: menuPopup.pad
                        spacing: 2

                        Repeater {
                            id: menuRepeater
                            model: menuOpener.children

                            // Each top-level row is styled here. Rows that carry
                            // children delegate their submenu to the native Qt
                            // menu (via QsMenuAnchor), so nested menus render in
                            // the system style while the root stays themed.
                            delegate: Item {
                                id: row
                                required property QsMenuEntry modelData

                                readonly property bool isSep: modelData.isSeparator
                                readonly property bool hasSub: modelData.hasChildren

                                readonly property var entry: modelData

                                width: menuColumn.width
                                height: isSep ? 9 : 26

                                // separator ────────────────────────────────
                                Rectangle {
                                    visible: row.isSep
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.1)
                                }

                                // row surface ──────────────────────────────
                                Rectangle {
                                    id: rowBody
                                    visible: !row.isSep
                                    anchors.fill: parent
                                    radius: 6
                                    color: (rowMa.containsMouse || row.hasSub && subAnchor.visible) && row.entry.enabled
                                           ? Qt.rgba(0.74, 0.58, 0.98, 0.22) : "transparent"

                                    Behavior on color {
                                        ColorAnimation { duration: 90 }
                                    }

                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        // check / radio glyph
                                        Text {
                                            Layout.preferredWidth: 12
                                            visible: row.entry.buttonType != QsMenuButtonType.None
                                            readonly property bool isChecked: row.entry.checkState == Qt.Checked || row.entry.checkState == Qt.PartiallyChecked
                                            text: {
                                                if (row.entry.buttonType == QsMenuButtonType.CheckBox)
                                                    return isChecked ? "\uf14a" : "\uf0c8";
                                                if (row.entry.buttonType == QsMenuButtonType.RadioButton)
                                                    return isChecked ? "\uf192" : "\uf10c";
                                                return "";
                                            }
                                            color: "#bd93f9"
                                            font {
                                                family: "Symbols Nerd Font Mono"
                                                pixelSize: 11
                                            }
                                            horizontalAlignment: Text.AlignHCenter
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // icon
                                        Image {
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            visible: row.entry.icon.length > 0
                                            source: row.entry.icon
                                            sourceSize: Qt.size(14, 14)
                                            fillMode: Image.PreserveAspectFit
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: row.entry.text
                                            color: row.entry.enabled ? "#f8f8f2" : Qt.rgba(1, 1, 1, 0.35)
                                            elide: Text.ElideRight
                                            font {
                                                pixelSize: 12
                                                family: "Quicksand"
                                            }
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // submenu chevron
                                        Text {
                                            Layout.preferredWidth: 10
                                            visible: row.entry.hasChildren
                                            text: "\uf054"
                                            color: row.entry.enabled ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.25)
                                            font {
                                                family: "Symbols Nerd Font Mono"
                                                pixelSize: 9
                                            }
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }
                                }

                                // native submenu anchor ────────────────────
                                QsMenuAnchor {
                                    id: subAnchor
                                    menu: row.hasSub ? row.entry : null
                                    anchor.window: menuPopup
                                    anchor.rect.x: menuPopup.contentItem.mapFromItem(row, row.width, 0).x
                                    anchor.rect.y: menuPopup.contentItem.mapFromItem(row, 0, 0).y
                                    anchor.rect.width: row.width
                                    anchor.rect.height: row.height
                                }

                                // hover + click driver ─────────────────────
                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor

                                    onContainsMouseChanged: {
                                        if (rowMa.containsMouse && row.hasSub)
                                            subAnchor.open();
                                    }

                                    onClicked: {
                                        if (row.isSep || !row.entry.enabled)
                                            return;
                                        if (row.hasSub) {
                                            subAnchor.open();
                                        } else {
                                            row.entry.triggered();
                                            delegate.menuOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
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
