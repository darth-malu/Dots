pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.themes
import qs.customItems

// ═══ POLKIT AUTHENTICATION AGENT ═══
// quickshell-hosted replacement for hyprpolkitagent: registers with the
// polkit authority on load and renders an on-theme auth prompt whenever a
// privileged action requests credentials. The whole PAM conversation is
// driven by PolkitAgent.flow — replies are submitted with flow.submit(),
// multi-turn sessions re-prompt automatically on failure.
Item {
    id: root

    PolkitAgent {
        id: agent
        path: "/org/quickshell/Polkit"
    }

    // full-desktop scrim window — blocks the rest of the screen while the
    // challenge is open and centers the card on the primary output
    PanelWindow {
        id: win
        visible: agent.isActive

        screen: null
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                root._cancel();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root._submit();
                event.accepted = true;
            }
        }

        // dim scrim
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        // ── prompt card ──
        Rectangle {
            id: card
            anchors.centerIn: parent

            implicitWidth: 350
            implicitHeight: col.implicitHeight + 24
            radius: 12
            color: Themes.popupCardBg
            border.width: 1
            border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.4)

            Behavior on border.color {
                ColorAnimation {
                    duration: 300
                }
            }

            ColumnLayout {
                id: col

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 12
                }
                spacing: 10

                // ── header — action name + the request source ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 9
                        color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.3)

                        Text {
                            anchors.centerIn: parent
                            // \uf023 — fa-lock
                            text: "\uf023"
                            color: Themes.accent
                            font {
                                pixelSize: 17
                                family: "Symbols Nerd Font Mono"
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root._title()
                            elide: Text.ElideRight
                            color: Themes.fg
                            font {
                                pixelSize: 13
                                bold: true
                                family: "Quicksand"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: agent.flow?.message ?? ""
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            color: Themes.dim
                            font {
                                pixelSize: 10
                                family: "ZedMono Nerd Font"
                            }
                        }
                    }
                }

                // ── identity rows — only shown when multiple are offered ──
                ColumnLayout {
                    id: identityCol

                    Layout.fillWidth: true
                    visible: agent.isActive && (agent.flow?.identities.length ?? 0) > 1
                    spacing: 4

                    Text {
                        text: "Authenticate as"
                        color: Themes.muted
                        font {
                            pixelSize: 9
                            bold: true
                            letterSpacing: 1.2
                            family: "Quicksand"
                        }
                    }

                    Repeater {
                        model: agent.flow ? agent.flow.identities : []

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool sel: agent.flow && agent.flow.selectedIdentity === modelData

                            Layout.fillWidth: true
                            implicitHeight: 26
                            radius: 6
                            color: mouse.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.12) : sel ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.2) : "transparent"
                            border.width: sel ? 1 : 0
                            border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.5)

                            Text {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10
                                }
                                text: modelData.displayName + (modelData.displayName === modelData.string ? "" : " (" + modelData.string + ")")
                                color: sel || mouse.containsMouse ? Themes.fg : Themes.dim
                                font {
                                    pixelSize: 11
                                    bold: sel
                                    family: "Quicksand"
                                }
                            }

                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: agent.flow.selectedIdentity = modelData
                            }
                        }
                    }
                }

                // ── password prompt — appears when the PAM convo asks ──
                ColumnLayout {
                    id: promptCol

                    Layout.fillWidth: true
                    visible: agent.isActive && agent.flow.isResponseRequired
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: agent.flow?.inputPrompt || "Password"
                        color: Themes.fg
                        font {
                            pixelSize: 10
                            bold: true
                            family: "Quicksand"
                        }
                    }

                    Field {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        echoMode: agent.flow?.responseVisible ?? false ? TextInput.Normal : TextInput.Password
                        selectByMouse: true
                        font.pixelSize: 11
                        placeholder: "password"
                        onReturnPressed: root._submit()
                        Component.onCompleted: forceActiveFocus()
                    }
                }

                // ── supplementary status line (info or error) ──
                Text {
                    Layout.fillWidth: true
                    visible: (agent.flow?.supplementaryMessage ?? "").length > 0
                    text: agent.flow?.supplementaryMessage ?? ""
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    color: agent.flow?.supplementaryIsError ?? false ? Themes.red : Themes.green
                    font {
                        pixelSize: 9
                        bold: true
                        family: "Quicksand"
                    }
                }

                // ── actions ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    MiniBtn {
                        text: "Cancel"
                        glyph: "\uf00d"
                        tint: Themes.muted
                        onClicked: root._cancel()
                    }

                    MiniBtn {
                        text: "Authenticate"
                        glyph: "\uf023"
                        tint: Themes.accent
                        active: agent.isActive && agent.flow.isResponseRequired
                        onClicked: root._submit()
                    }
                }
            }
        }
    }

    // a readable title — prefer the action id's last component, else "Authorize"
    function _title(): string {
        const a = agent.flow?.actionId ?? "";
        if (a.length === 0)
            return "Authorize";
        const i = a.lastIndexOf(".");
        return i >= 0 ? a.slice(i + 1).replace(/-/g, " ") : a;
    }

    function _submit(): void {
        if (!agent.flow?.isResponseRequired)
            return;
        const value = inputField.text;
        inputField.clear();
        agent.flow.submit(value);
    }

    function _cancel(): void {
        if (agent.flow)
            agent.flow.cancelAuthenticationRequest();
    }

    // hand a fresh prompt keyboard focus as soon as it needs input
    Connections {
        target: agent
        function onAuthenticationRequestStarted(): void {
            inputField.clear();
        }
    }

    Connections {
        target: agent.flow
        enabled: agent.flow != null
        function onIsResponseRequiredChanged(): void {
            if (agent.flow?.isResponseRequired)
                inputField.forceActiveFocus();
        }
    }
}
