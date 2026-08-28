pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.themes

// Calculator rofi:
// · type an expression (keyboard) or tap the keypad grid
// · live result preview underneath the input
// · Enter / the copy button dumps the result to the clipboard and closes
// · "=" / `=` button keeps the result in the field so you can chain more math
PanelWindow {
    id: root

    visible: RofiState.toggleCalc
    implicitWidth: 320
    implicitHeight: col.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // ── expression state ──
    property string expression: ""
    property bool justEvaluated: false

    readonly property string resultText: buildResult(expression)
    readonly property bool exprValid: resultText.length > 0

    onVisibleChanged: {
        if (visible) {
            expressionField.forceActiveFocus();
            expressionField.selectAll();
        }
    }

    function close() {
        RofiState.toggleCalc = false;
        searchReset = false;
        expression = "";
    }

    property bool searchReset: false

    function copyResult() {
        if (!root.exprValid)
            return;
        const res = root.resultText;
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + shQuote(res) + " | wl-copy"]);
        Quickshell.execDetached(["notify-send", "-a", "Calc", "-t", "1500", "\uf1ec  " + res + " copied to clipboard"]);
        close();
    }

    function setExpression(s) {
        root.justEvaluated = false;
        root.expression = s;
    }

    function append(tok) {
        if (root.justEvaluated)
            // operator → keep chaining from the result; digit/`.` → fresh start
            root.expression = /[0-9.]/.test(tok) ? tok : root.expression + tok;
        else
            root.expression += tok;
        root.justEvaluated = false;
    }

    function doEquals() {
        if (!root.exprValid)
            return;
        root.expression = root.resultText;
        root.justEvaluated = true;
        expressionField.selectAll();
    }

    function shQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    // ── minimal, eval-free math evaluator ──
    // recursive descent over a tiny token stream: numbers, + - * / % ^ and ()
    property var _toks: []
    property int _pos: 0

    function buildResult(s) {
        const toks = tokenize(s);
        if (!toks || toks.length === 0)
            return "";
        _toks = toks;
        _pos = 0;
        let v;
        try {
            v = parseAdditive();
            if (_pos !== _toks.length)
                return "";
        } catch (e) {
            return "";
        }
        if (!isFinite(v))
            return "";
        let out = String(Math.round(v * 1e10) / 1e10);
        if (out.indexOf("e") === -1 && out.indexOf(".") !== -1)
            out = out.replace(/0+$/, "").replace(/\.$/, "");
        return out;
    }

    function tokenize(s) {
        const out = [];
        let i = 0;
        while (i < s.length) {
            const c = s[i];
            if (c === " " || c === "\u00d7" || c === "\u00f7") { i++; continue; }
            if ((c >= "0" && c <= "9") || c === ".") {
                let j = i;
                while (j < s.length && ((s[j] >= "0" && s[j] <= "9") || s[j] === "."))
                    j++;
                out.push({ t: "num", v: parseFloat(s.slice(i, j)) });
                i = j;
                continue;
            }
            if ("+-*/%^()".includes(c)) {
                out.push({ t: "op", v: c });
                i++;
                continue;
            }
            return null;
        }
        return out;
    }

    function peek() { return _toks[_pos]; }
    function next() { const t = _toks[_pos]; _pos++; return t; }

    function parseFactor() {
        const t = peek();
        if (!t)
            throw Error();
        if (t.t === "num") { _pos++; return t.v; }
        if (t.t === "op" && (t.v === "+" || t.v === "-")) {
            _pos++;
            return (t.v === "-" ? -1 : 1) * parseFactor();
        }
        if (t.t === "op" && t.v === "(") {
            _pos++;
            const v = parseAdditive();
            const c = peek();
            if (!c || c.t !== "op" || c.v !== ")")
                throw Error();
            _pos++;
            return v;
        }
        throw Error();
    }

    function parsePower() {
        let base = parseFactor();
        const t = peek();
        if (t && t.t === "op" && t.v === "^") {
            _pos++;
            base = Math.pow(base, parsePower());
        }
        return base;
    }

    function parseTerm() {
        let v = parsePower();
        while (true) {
            const t = peek();
            if (!t || t.t !== "op")
                break;
            if (t.v === "*") { _pos++; v *= parsePower(); }
            else if (t.v === "/") {
                _pos++;
                const d = parsePower();
                if (d === 0)
                    throw Error();
                v /= d;
            } else if (t.v === "%") {
                _pos++;
                const d = parsePower();
                if (d === 0)
                    throw Error();
                v %= d;
            } else
                break;
        }
        return v;
    }

    function parseAdditive() {
        let v = parseTerm();
        while (true) {
            const t = peek();
            if (!t || t.t !== "op")
                break;
            if (t.v === "+") { _pos++; v += parseTerm(); }
            else if (t.v === "-") { _pos++; v -= parseTerm(); }
            else
                break;
        }
        return v;
    }

    // ── UI ──
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Themes.launcherBg
        border.width: 1
        border.color: Themes.rofiBorder

        ColumnLayout {
            id: col

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            // ── header — mode glyph · expression field · copy button ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "\uf1ec"
                    color: root.exprValid ? Themes.rofiAccent : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.4)
                    font { pixelSize: 13; family: "Symbols Nerd Font Mono" }
                }

                TextField {
                    id: expressionField

                    Layout.fillWidth: true
                    color: Themes.windowTextColor
                    selectByMouse: true
                    horizontalAlignment: TextInput.AlignRight
                    font { pixelSize: 18; family: "ZedMono Nerd Font" }
                    background: Rectangle {
                        color: Qt.rgba(1, 1, 1, 0.05)
                        implicitHeight: 30
                        radius: 6
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                    }
                    onTextChanged: root.justEvaluated = false
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.copyResult();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.close();
                            event.accepted = true;
                        }
                    }
                }

                // copy button
                Rectangle {
                    id: copyBt

                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 6
                    color: copyMa.containsMouse ? Qt.rgba(Themes.rofiAccent.r, Themes.rofiAccent.g, Themes.rofiAccent.b, 0.18) : "transparent"
                    border.width: 1
                    border.color: copyMa.containsMouse ? Themes.rofiAccent : Qt.rgba(1, 1, 1, 0.1)
                    opacity: root.exprValid ? 1 : 0.4

                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0c5"
                        color: Themes.rofiAccent
                        font { pixelSize: 11; family: "Symbols Nerd Font Mono" }
                    }

                    MouseArea {
                        id: copyMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyResult()
                    }
                }
            }

            // ── live result preview ──
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: {
                    if (!root.expression)
                        return "";
                    return root.exprValid ? "= " + root.resultText : "= invalid";
                }
                color: root.exprValid ? "#50fa7b" : "#ff5555"
                font { pixelSize: 11; family: "ZedMono Nerd Font" }
                elide: Text.ElideRight
            }

            // ── keypad ──
            GridLayout {
                id: keypad

                Layout.fillWidth: true
                columns: 4
                columnSpacing: 6
                rowSpacing: 6

                function press(tok) {
                    root.append(tok);
                    expressionField.forceActiveFocus();
                }
                function clear() {
                    root.setExpression("");
                    expressionField.forceActiveFocus();
                }
                function backspace() {
                    root.setExpression(root.expression.slice(0, -1));
                    expressionField.forceActiveFocus();
                }
                function equals() {
                    root.doEquals();
                    expressionField.forceActiveFocus();
                }

                component Key: Rectangle {
                    id: key

                    property string label: ""
                    property string tok: label
                    property bool accent: false
                    property var keypadAction

                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 7
                    color: keyMa.containsMouse
                        ? (accent ? Qt.rgba(Themes.rofiAccent.r, Themes.rofiAccent.g, Themes.rofiAccent.b, 0.35) : Qt.rgba(1, 1, 1, 0.1))
                        : (accent ? Qt.rgba(Themes.rofiAccent.r, Themes.rofiAccent.g, Themes.rofiAccent.b, 0.22) : Qt.rgba(1, 1, 1, 0.05))
                    border.width: 1
                    border.color: keyMa.containsMouse
                        ? (accent ? Themes.rofiAccent : Qt.rgba(1, 1, 1, 0.18))
                        : Qt.rgba(1, 1, 1, 0.08)

                    scale: keyMa.pressed ? 0.93 : 1
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: key.label
                        color: key.accent ? Themes.accent : Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 1)
                        font { pixelSize: 15; family: "Symbols Nerd Font Mono" }
                    }

                    MouseArea {
                        id: keyMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (key.keypadAction)
                                key.keypadAction();
                            else
                                keypad.press(key.tok);
                            expressionField.forceActiveFocus();
                        }
                    }
                }

                Key { label: "7"; tok: "7" }
                Key { label: "8"; tok: "8" }
                Key { label: "9"; tok: "9" }
                Key { label: "÷"; tok: "/" }

                Key { label: "4"; tok: "4" }
                Key { label: "5"; tok: "5" }
                Key { label: "6"; tok: "6" }
                Key { label: "×"; tok: "*" }

                Key { label: "1"; tok: "1" }
                Key { label: "2"; tok: "2" }
                Key { label: "3"; tok: "3" }
                Key { label: "−"; tok: "-" }

                Key { label: "0"; tok: "0" }
                Key { label: "."; tok: "." }
                Key { label: "⌫"; keypadAction: () => keypad.backspace() }
                Key { label: "+"; tok: "+" }

                Key { label: "("; tok: "(" }
                Key { label: ")"; tok: ")" }
                Key { label: "C"; keypadAction: () => keypad.clear() }
                Key { label: "="; accent: true; keypadAction: () => keypad.equals() }
            }

            // ── hint ──
            Text {
                Layout.fillWidth: true
                text: "enter copy · = chain · esc close"
                color: Qt.rgba(Themes.rofiDelegateText.r, Themes.rofiDelegateText.g, Themes.rofiDelegateText.b, 0.35)
                font { pixelSize: 8; letterSpacing: 1; family: "ZedMono Nerd Font" }
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.close()
    }
}