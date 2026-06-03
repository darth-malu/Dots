import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
  id: root

  FileView {
    id: quoteF
    path: Qt.resolvedUrl("./quotes.txt")
    watchChanges: true
    onFileChanged: reload()
    blockLoading: true
  }
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panelWindow
      WlrLayershell.layer: WlrLayer.Background
      required property var modelData
      screen: modelData
      anchors {
        bottom: true
        left: true
      }
      implicitWidth: 500
      implicitHeight: 60
      color: "transparent"
      Rectangle {
        id: background
        anchors.fill: parent
        radius: 20
        color: "#7b5d3e"
        border {
          width: 2
          color: "#ffa750"
        }
        Text {
          id: quote
          text: "No Quotes"
          color: "#fff"
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
          }
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          Component.onCompleted: {
            background.setQuoteRandom()
          }
        }
        function setQuoteRandom() {
          let quotes = quoteF.text().split(";\n");
          quote.text = quotes[Math.floor(Math.random() * quotes.length)];
        }
        MouseArea {
          anchors.fill: parent
          onClicked: background.setQuoteRandom()
        }
      }
    }
  }
}