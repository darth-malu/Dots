pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
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

    // ── primary action button — richer than MiniBtn, fills accent ──
    component PromptBtn: Rectangle {
        id: pb

        signal clicked

        required property string text
        required property color tint
        property string glyph: ""
        property bool primary: false
        property bool enabled: true

        opacity: pb.enabled ? 1 : 0.45

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        implicitWidth: contentRow.implicitWidth + 18
        implicitHeight: 30
        radius: 9

        color: pb.primary
            ? pb.tint
            : pwrMa.containsMouse ? Qt.rgba(pb.tint.r, pb.tint.g, pb.tint.b, 0.2) : Qt.rgba(1, 1, 1, 0.06)
        border.width: pb.primary ? 0 : 1
        border.color: pwrMa.containsMouse ? Qt.rgba(pb.tint.r, pb.tint.g, pb.tint.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                visible: pb.glyph.length > 0
                text: pb.glyph
                color: pb.primary ? Themes.fg : pwrMa.containsMouse ? pb.tint : Themes.dim
                font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
            }

            Text {
                text: pb.text
                color: pb.primary ? Themes.fg : pwrMa.containsMouse ? pb.tint : Themes.dim
                font { pixelSize: 10; bold: true; family: "Quicksand" }
            }
        }

        MouseArea {
            id: pwrMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: pb.enabled
            onClicked: pb.clicked()
        }
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

        // keybind host — a real Item so Keys can attach (the panel
        // interface itself isn't an Item)
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    root._cancel();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root._submit();
                    event.accepted = true;
                }
            }
        }

        // dim scrim
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
        }

        // ── prompt card ──
        Rectangle {
            id: card
            anchors.centerIn: parent

            implicitWidth: 400
            implicitHeight: col.implicitHeight + 36
            radius: 18
            color: Themes.popupCardBg
            border.width: 1
            border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.5)

            Behavior on border.color {
                ColorAnimation { duration: 300 }
            }

            // entrance — slides up softly when the window appears
            scale: win.visible ? 1 : 0.94
            opacity: win.visible ? 1 : 0

            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutBack }
            }
            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.6
                shadowColor: Qt.rgba(0, 0, 0, 0.6)
                shadowOpacity: 0.5
            }

            ColumnLayout {
                id: col

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 22
                    leftMargin: 18
                    rightMargin: 18
                }
                spacing: 12

                // ── header — action glyph + title + caption ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        implicitWidth: 46
                        implicitHeight: 46
                        radius: 13
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.28)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.1)
                            }
                        }
                        border.width: 1
                        border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.4)

                        Text {
                            anchors.centerIn: parent
                            // \uf3ed — fa-shield-alt
                            text: "\uf3ed"
                            color: Themes.accent
                            font { pixelSize: 21; family: "Symbols Nerd Font Mono" }
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
                            font { pixelSize: 15; bold: true; family: "Quicksand" }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "authentication required"
                            color: Themes.dim
                            font { pixelSize: 9; bold: true; letterSpacing: 2; family: "Quicksand" }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (agent.flow?.message ?? "").length > 0
                            text: agent.flow?.message ?? ""
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            color: Themes.muted
                            font { pixelSize: 10; family: "ZedMono Nerd Font" }
                            Layout.topMargin: 2
                        }
                    }
                }

                // ── accent divider ──
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    radius: 1
                    color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.25)
                }

                // ── identity rows — only shown when multiple are offered ──
                ColumnLayout {
                    id: identityCol

                    Layout.fillWidth: true
                    visible: agent.isActive && (agent.flow?.identities.length ?? 0) > 1
                    spacing: 5

                    Text {
                        text: "Authenticate as"
                        color: Themes.muted
                        font { pixelSize: 9; bold: true; letterSpacing: 1.6; family: "Quicksand" }
                    }

                    Repeater {
                        model: agent.flow ? agent.flow.identities : []

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool sel: agent.flow && agent.flow.selectedIdentity === modelData

                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 8
                            color: mouse.containsMouse ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.12) : sel ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: sel ? 1 : 0
                            border.color: Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.5)

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                // radio dot
                                Rectangle {
                                    implicitWidth: 9
                                    implicitHeight: 9
                                    radius: 4.5
                                    color: sel || mouse.containsMouse
                                        ? Themes.accent
                                        : Qt.rgba(Themes.dim.r, Themes.dim.g, Themes.dim.b, 0.5)
                                    border.width: sel ? 0 : 1
                                    border.color: Qt.rgba(Themes.dim.r, Themes.dim.g, Themes.dim.b, 0.6)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.displayName + (modelData.displayName === modelData.string ? "" : " (" + modelData.string + ")")
                                    color: sel || mouse.containsMouse ? Themes.fg : Themes.dim
                                    font { pixelSize: 11; bold: sel; family: "Quicksand" }
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
                        text: (agent.flow?.inputPrompt || "Password").toUpperCase()
                        color: Themes.fg
                        font { pixelSize: 9; bold: true; letterSpacing: 1.6; family: "Quicksand" }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: inputField.activeFocus
                            ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.6)
                            : Themes.separator

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                // \uf084 — fa-key
                                text: "\uf084"
                                color: inputField.activeFocus ? Themes.accent : Themes.dim
                                font { pixelSize: 12; family: "Symbols Nerd Font Mono" }
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            Field {
                                id: inputField
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                textPixelSize: 12
                                echoMode: agent.flow?.responseVisible ?? false ? TextInput.Normal : TextInput.Password
                                selectByMouse: true
                                placeholder: "password"
                                background: Item {}
                                onReturnPressed: root._submit()
                                Component.onCompleted: forceActiveFocus()
                            }
                        }
                    }
                }

                // ── supplementary status line (info or error), chipped ──
                Rectangle {
                    Layout.fillWidth: true
                    visible: (agent.flow?.supplementaryMessage ?? "").length > 0
                    implicitHeight: statusText.implicitHeight + 10
                    radius: 7
                    color: agent.flow?.supplementaryIsError ?? false
                        ? Qt.rgba(Themes.red.r, Themes.red.g, Themes.red.b, 0.12)
                        : Qt.rgba(Themes.green.r, Themes.green.g, Themes.green.b, 0.12)
                    border.width: 1
                    border.color: agent.flow?.supplementaryIsError ?? false
                        ? Qt.rgba(Themes.red.r, Themes.red.g, Themes.red.b, 0.35)
                        : Qt.rgba(Themes.green.r, Themes.green.g, Themes.green.b, 0.35)

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        width: parent.width - 16
                        text: agent.flow?.supplementaryMessage ?? ""
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        color: agent.flow?.supplementaryIsError ?? false ? Themes.red : Themes.green
                        font { pixelSize: 9; bold: true; family: "Quicksand" }
                    }
                }

                // ── actions ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    Text {
                        text: "↵ submit"
                        color: Themes.dim
                        visible: agent.flow?.isResponseRequired ?? false
                        font { pixelSize: 8; family: "Quicksand"; letterSpacing: 0.5 }
                        opacity: 0.6
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    PromptBtn {
                        text: "Cancel"
                        glyph: "\uf00d"
                        tint: Themes.muted
                        onClicked: root._cancel()
                    }

                    PromptBtn {
                        text: "Authenticate"
                        glyph: "\uf00c"
                        tint: Themes.accent
                        primary: true
                        enabled: agent.isActive && agent.flow.isResponseRequired
                        onClicked: root._submit()
                    }
                }

                // ── faint footer — full action id for power users ──
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    visible: (agent.flow?.actionId ?? "").length > 0
                    text: agent.flow?.actionId ?? ""
                    elide: Text.ElideRight
                    color: Themes.muted
                    font { pixelSize: 7; family: "ZedMono Nerd Font" }
                    opacity: 0.5
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
            // the prompt window may not be visible yet — retry until it is
            const focusPass = function (n: int): void {
                if (inputField.visible) {
                    inputField.forceActiveFocus();
                    return;
                }
                if (n > 0)
                    Qt.callLater(() => focusPass(n - 1));
            };
            focusPass(10);
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