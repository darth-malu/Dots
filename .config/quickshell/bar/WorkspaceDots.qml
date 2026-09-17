pragma ComponentBehavior: Bound
import QtQuick
import qs.themes
import qs.services
import Quickshell.Hyprland
import QtQuick.Layouts

// GNOME-inspired workspace indicator — a row of dots, one per workspace,
// with the active workspace drawn as an elongated accent pill. Replaces the
// plain workspace numbers when MiscState.dotWorkspaces is enabled.
RowLayout {
    id: root

    spacing: 2

    readonly property int wsRev: WorkspaceService.revision

    readonly property var workspaceList: {
        const rev = wsRev;
        const list = [...Hyprland.workspaces.values].filter(ws => {
            if (!ws || (ws.name ?? "").includes("special"))
                return false;
            // adaptive workspaces — hide empty ones unless we're sitting on it
            if (!(ws?.toplevels?.values?.length ?? 0) && !(ws?.active ?? false))
                return false;
            return true;
        });
        list.sort((a, b) => String(a.name ?? 0).localeCompare(String(b.name ?? 0), undefined, {
                numeric: true
            }));
        return list;
    }

    Repeater {
        model: root.workspaceList

        delegate: Item {
            id: dot

            required property var modelData

            readonly property var ws: modelData
            readonly property bool isActive: ws?.active ?? false
            readonly property bool isUrgent: ws?.urgent ?? false
            readonly property bool hovered: dotMa.containsMouse

            // fixed slot so the row never reflows — only the pill animates
            implicitWidth: 16
            implicitHeight: 10
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: pill

                anchors.centerIn: parent
                height: 6
                width: dot.isActive ? 16 : 6
                radius: height / 2
                color: dot.isUrgent && !dot.isActive ? "#ff5555"
                    : dot.isActive ? Themes.accent
                    : dot.hovered ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.6)
                    : Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.28)

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }
            }

            MouseArea {
                id: dotMa

                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (dot.ws)
                        HyprlandService.gotoWorkspace(dot.ws.name);
                }
            }

            SequentialAnimation on opacity {
                running: dot.isUrgent && !dot.isActive
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation {
                    to: 0.45
                    duration: 420
                }
                NumberAnimation {
                    to: 1
                    duration: 420
                }
            }
        }
    }
}
