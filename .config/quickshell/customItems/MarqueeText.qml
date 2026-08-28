import QtQuick
import qs.themes

// Scrolling overflow label — two copies chase each other with a pause between
// loops; renders as a static label when the text fits.
// Self-sizes to min(maxWidth, text width); in a layout with fillWidth the
// layout assigns width and scrolling kicks in whenever the text overflows.
Item {
    id: root

    required property string text
    required property int maxWidth
    // master switch — off renders a plain elided label instead of scrolling
    property bool scrolling: true
    property string fontFamily: "Quicksand"
    property bool fontBold: true
    property int pixelSize: 11
    property color textColor: Themes.fg
    property real pxPerSec: 26
    property int pauseMs: 1600

    // sizing goes through implicitWidth so layouts can manage this item —
    // a direct width binding fights RowLayout and overflows onto neighbours
    implicitWidth: Math.min(maxWidth, metrics.implicitWidth)
    implicitHeight: metrics.implicitHeight
    width: implicitWidth
    clip: true

    Text {
        id: metrics
        visible: false
        text: root.text
        font.family: root.fontFamily
        font.bold: root.fontBold
        font.pixelSize: root.pixelSize
    }

    Text {
        id: copy1
        visible: root.scrolling
        y: (root.height - height) / 2
        x: 0
        text: root.text
        font: metrics.font
        color: root.textColor
    }

    // static elided label used when scrolling is disabled
    Text {
        anchors.fill: parent
        visible: !root.scrolling
        text: root.text
        font: metrics.font
        color: root.textColor
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        id: copy2
        y: copy1.y
        text: root.text
        font: metrics.font
        color: root.textColor
        visible: scrollAnim.running
    }

    SequentialAnimation {
        id: scrollAnim
        loops: Animation.Infinite
        running: false

        PauseAnimation {
            duration: root.pauseMs
        }

        NumberAnimation {
            target: copy1
            property: "x"
            from: 0
            to: -(metrics.implicitWidth + 24)
            duration: Math.max(1200, (metrics.implicitWidth + 24) / root.pxPerSec * 1000)
            easing.type: Easing.Linear
        }

        ScriptAction {
            script: {
                copy1.x = 0;
                copy2.x = metrics.implicitWidth + 24;
            }
        }
    }

    Connections {
        target: copy1
        function onXChanged() {
            if (scrollAnim.running)
                copy2.x = copy1.x + metrics.implicitWidth + 24;
        }
    }

    function restartAnimation() {
        scrollAnim.stop();
        if (root.scrolling && metrics.implicitWidth > root.width) {
            copy1.x = 0;
            copy2.x = metrics.implicitWidth + 24;
            scrollAnim.start();
        } else {
            copy1.x = 0;
        }
    }

    onScrollingChanged: restartAnimation()
    Component.onCompleted: restartAnimation()
    onTextChanged: restartAnimation()
    onWidthChanged: restartAnimation()
}
