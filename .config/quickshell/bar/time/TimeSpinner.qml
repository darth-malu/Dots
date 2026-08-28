import QtQuick
import QtQuick.Layouts
import qs.services
import qs.themes

// HH:MM entry with individually scrollable hour / minute segments.
// Defaults to the shared clock (TimeService) snapped to 5 minutes — or
// plain 00:00 when zeroDefault is set (countdown durations). Scroll,
// arrow keys or typing all adjust it. dirty flips on first interaction.
//
// Layout: ┌──────┐   ┌──────┐
//         │  hh  │ : │  mm  │
RowLayout {
    id: root

    spacing: 3

    // countdown-style entry: reset()/creation snap to 00:00 instead of the wall clock
    property bool zeroDefault: false

    property string hours: "00"
    property string minutes: "00"
    // becomes true after the first wheel step / edit of either segment
    property bool dirty: false

    readonly property string timeString: hours + ":" + minutes

    Component.onCompleted: root.reset()

    function reset() {
        let hh = "00";
        let mm = "00";
        if (!zeroDefault) {
            // read through the singleton so the value always matches the bar clock
            const now = TimeService.currentDate;
            hh = String(now.getHours()).padStart(2, "0");
            // snap minutes to the 5-minute wheel grid
            mm = String(Math.round(now.getMinutes() / 5) * 5 % 60).padStart(2, "0");
        }
        hours = hh;
        minutes = mm;
        dirty = false;
        hhSeg.input.text = hh;
        mmSeg.input.text = mm;
    }

    // programmatic entry that stays "clean" — used to pre-load an existing
    // reminder's time without tripping the dirty-focus side effects
    function setTime(hh, mm) {
        hours = String(Math.max(0, Math.min(23, parseInt(hh) || 0))).padStart(2, "0");
        minutes = String(Math.max(0, Math.min(59, parseInt(mm) || 0))).padStart(2, "0");
        hhSeg.input.text = hours;
        mmSeg.input.text = minutes;
    }

    function _setHours(v) {
        dirty = true;
        hours = String(((Math.round(v) % 24) + 24) % 24).padStart(2, "0");
    }

    function _setMinutes(v) {
        dirty = true;
        minutes = String(((Math.round(v) % 60) + 60) % 60).padStart(2, "0");
    }

    component Segment: Rectangle {
        id: seg

        property string label
        property alias input: segInput
        property int step // wheel delta per notch
        signal stepped(int delta)
        signal edited(string text)

        function commitEdit() {
            const v = parseInt(segInput.text);
            if (!isNaN(v))
                edited(v);
            else
                segInput.text = label;
        }

        implicitWidth: 42
        implicitHeight: 40
        radius: 10

        readonly property bool focused: segInput.activeFocus
        // quiet idle → soft hover lift → lavender focus ring
        color: focused ? Qt.rgba(Themes.accent.r, Themes.accent.g, Themes.accent.b, 0.14)
            : segHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
        border.width: focused ? 1.5 : 1
        border.color: focused ? Themes.accent : segHover.hovered ? "#565d78" : "#3b3f54"

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        TextInput {
            id: segInput

            anchors.centerIn: parent
            width: parent.width - 8
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            // plain initial value — the Connections blocks below keep it in
            // sync with root state without fighting manual edits
            text: parent.label
            color: Themes.accentSoft
            font {
                pixelSize: 17
                weight: Font.DemiBold
                family: "ZedMono Nerd Font"
            }
            maximumLength: 2
            validator: RegularExpressionValidator { regularExpression: /[0-9]{0,2}/ }
            selectByMouse: true
            activeFocusOnTab: true
            cursorVisible: activeFocus

            // click anywhere on the chip focuses and selects for typing
            TapHandler {
                onTapped: {
                    segInput.forceActiveFocus();
                    segInput.selectAll();
                }
            }

            onAccepted: parent.commitEdit()
            Keys.onReturnPressed: segInput.focus = false
            Keys.onEnterPressed: segInput.focus = false
            Keys.onEscapePressed: {
                segInput.text = parent.label;
                segInput.focus = false;
            }
            Keys.onUpPressed: parent.stepped(parent.step)
            Keys.onDownPressed: parent.stepped(-parent.step)
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => parent.stepped(ev.angleDelta.y > 0 ? parent.step : -parent.step)
        }

        HoverHandler {
            id: segHover
        }
    }

    Segment {
        id: hhSeg

        label: root.hours
        step: 1
        onStepped: d => root._setHours(parseInt(root.hours) + d)
        onEdited: t => root._setHours(parseInt(t))

        Connections {
            target: root

            function onHoursChanged() {
                if (!hhSeg.input.activeFocus)
                    hhSeg.input.text = root.hours;
            }
        }
    }

    Text {
        text: ":"
        color: hhSeg.focused || mmSeg.focused ? Themes.accent : "#4c5069"
        font { pixelSize: 18; bold: true; family: "ZedMono Nerd Font" }
    }

    Segment {
        id: mmSeg

        label: root.minutes
        step: 5
        onStepped: d => root._setMinutes(parseInt(root.minutes) + d)
        onEdited: t => {
            let v = parseInt(t);
            if (v > 59)
                v = 59;
            root._setMinutes(v);
        }

        Connections {
            target: root

            function onMinutesChanged() {
                if (!mmSeg.input.activeFocus)
                    mmSeg.input.text = root.minutes;
            }
        }
    }

}
