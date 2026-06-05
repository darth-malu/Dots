import QtQuick
import qs.services
import qs.customItems
import Quickshell.Io
import QtQuick.Layouts

Loader {
    id: loaderBig
    active: NetworkState.netspeedVisible
    visible: active

    sourceComponent: BarBlock {
        id: root
        implicitHeight: childrenRect.height
        implicitWidth: childrenRect.width

        color: 'transparent'

        property int refreshInterval: 1000
        property string iface

        property real rxRate
        property real txRate
        property real rxPrev: 0
        property real txPrev: 0

        Process {
            id: defaultInterface
            command: ["ip", "route"]
            running: false

            stdout: SplitParser {
                onRead: data => {
                    if (data.startsWith("default via")) {
                        let line = data.split(/\s/);
                        let devIndex = line.indexOf("dev");
                        if (devIndex !== -1)
                            root.iface = line[devIndex + 1];
                    }
                }
            }
        }

        Process {
            id: getRxTxBytes
            command: ["cat", "/proc/net/dev"]
            running: false

            stdout: SplitParser {
                onRead: data => {
                    data = data.trim();
                    if (data.startsWith(root.iface + ":")) {
                        const parts = data.split(/\s+/);

                        let rx = parseInt(parts[1]);
                        let tx = parseInt(parts[9]);

                        if (root.rxPrev > 0) {
                            root.rxRate = ((rx - root.rxPrev) * 8) / 1000000;
                            root.txRate = ((tx - root.txPrev) * 8) / 1000000;
                        }

                        root.rxPrev = rx;
                        root.txPrev = tx;
                    }
                }
            }
        }

        Timer {
            interval: root.refreshInterval
            running: true
            repeat: true
            onTriggered: () => {
                defaultInterface.running = true;
                getRxTxBytes.running = true;
            }
        }

        content: RowLayout {
            spacing: 6

            RowLayout {
                spacing: 4
                Text {
                    text: ""
                    color: "#89dceb"
                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                }
                BarText {
                    text: root.rxRate === 0 ? "-" : root.rxRate.toFixed(1)
                    color: "#89dceb"
                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                }
            }

            Rectangle {
                implicitWidth: 1; implicitHeight: 10
                color: "#45475a"
            }

            RowLayout {
                spacing: 4
                Text {
                    text: ""
                    color: "#f5c2e7"
                    font { pixelSize: 10; family: "Symbols Nerd Font Mono" }
                }
                BarText {
                    text: root.txRate === 0 ? "-" : root.txRate.toFixed(1)
                    color: "#f5c2e7"
                    font { pixelSize: 10; family: "ZedMono Nerd Font" }
                }
            }
        }
    }
}
