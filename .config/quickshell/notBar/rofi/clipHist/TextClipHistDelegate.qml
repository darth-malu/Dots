import QtQuick
import qs.themes

Row {
    spacing: 8

    // image entries get a small badge so they scan at a glance
    Rectangle {
        visible: modelData.indexOf("(image)") !== -1
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: imgGlyph.implicitWidth + 6
        implicitHeight: imgGlyph.implicitHeight + 2
        radius: 4
        color: Qt.rgba(0.741, 0.576, 0.976, 0.18)

        Text {
            id: imgGlyph
            anchors.centerIn: parent
            text: "\uf03e"
            color: "#bd93f9"
            font { pixelSize: 9; family: "Symbols Nerd Font Mono" }
        }
    }

    Text {
        id: modelText
        anchors.verticalCenter: parent.verticalCenter
        text: modelData.replace(/^([0-9]+)\t/, "").replace(/\n/g, " ")
        color: Themes.rofiDelegateText
        font: Themes.rofiFont
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}
