import QtQuick
import QtQuick.Layouts

Rectangle {
    id: rootCard
    Layout.fillWidth: true
    Layout.preferredHeight: TailscaleSvc.running ? (110 + (TailscaleSvc.peers.length * 32)) : 64
    radius: 16
    color: Theme.cardBg
    border.color: TailscaleSvc.running ? Theme.green : Theme.border
    border.width: 1

    Behavior on Layout.preferredHeight {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text { text: "🔒"; font.pixelSize: 14 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "Tailscale VPN"; color: Theme.fg; font.bold: true; font.pixelSize: 12 }
                Text { 
                    text: TailscaleSvc.running ? (TailscaleSvc.tailnet !== "" ? TailscaleSvc.tailnet : "Connected") : "Disconnected"
                    color: TailscaleSvc.running ? Theme.green : Theme.muted
                    font.pixelSize: 10 
                }
            }

            Rectangle {
                width: 36; height: 20; radius: 10
                color: TailscaleSvc.running ? Theme.green : Theme.border
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 16; height: 16; radius: 8
                    color: Theme.fg
                    y: 2
                    x: TailscaleSvc.running ? 18 : 2
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TailscaleSvc.toggle()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            visible: TailscaleSvc.running

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: 4; Layout.bottomMargin: 4 }

            Text { text: "DEVICES & PEERS"; color: Theme.muted; font.pixelSize: 9; font.bold: true }

            Repeater {
                model: TailscaleSvc.peers
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 8

                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: modelData.online ? Theme.green : Theme.muted
                    }

                    Text {
                        text: modelData.host || modelData.dns || "Unknown"
                        color: Theme.fg
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.ips.length > 0 ? modelData.ips[0] : ""
                        color: Theme.muted
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.ips.length > 0) {
                                TailscaleSvc.copyIp(modelData.ips[0]);
                            }
                        }
                    }
                }
            }
        }
    }
}
