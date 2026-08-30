import QtQuick
import QtQuick.Layouts

Rectangle {
    id: rootCard
    Layout.fillWidth: true
    Layout.preferredHeight: TailscaleSvc.running ? (110 + (TailscaleSvc.peers.length * 32)) : 64
    radius: 16
    color: "#141418"
    border.color: TailscaleSvc.running ? "#00FF88" : "#2A2A32"
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
                Text { text: "Tailscale VPN"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 12 }
                Text { 
                    text: TailscaleSvc.running ? (TailscaleSvc.tailnet !== "" ? TailscaleSvc.tailnet : "Connected") : "Disconnected"
                    color: TailscaleSvc.running ? "#00FF88" : "#888888"
                    font.pixelSize: 10 
                }
            }

            Rectangle {
                width: 36; height: 20; radius: 10
                color: TailscaleSvc.running ? "#00FF88" : "#2A2A2E"
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 16; height: 16; radius: 8
                    color: "#FFFFFF"
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

            Rectangle { Layout.fillWidth: true; height: 1; color: "#222228"; Layout.topMargin: 4; Layout.bottomMargin: 4 }

            Text { text: "DEVICES & PEERS"; color: "#666670"; font.pixelSize: 9; font.bold: true }

            Repeater {
                model: TailscaleSvc.peers
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 8

                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: modelData.online ? "#00FF88" : "#555555"
                    }

                    Text {
                        text: modelData.host || modelData.dns || "Unknown"
                        color: "#CCCCCC"
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.ips.length > 0 ? modelData.ips[0] : ""
                        color: "#777780"
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
