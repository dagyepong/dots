import QtQuick
import qs.theme
import qs.services
import qs.widgets

Item {
    id: root

    signal back()
    property bool embedded: false      // inside the Settings window: no back arrow

    property string asking: ""          // SSID whose password is being asked
    readonly property bool needsKeyboard: asking !== ""

    width: 360
    height: 440

    onVisibleChanged: {
        asking = ""
        if (visible) Network.scan()
    }

    Timer {
        running: root.visible
        interval: 10000
        repeat: true
        onTriggered: Network.scan()
    }

    PageHeader {
        showBack: !root.embedded
        x: 14; y: 14
        width: root.width - 28
        title: "Wi-Fi"
        showSwitch: true
        checked: Network.wifiOn
        onBack: root.back()
        onToggled: Network.setWifi(!Network.wifiOn)
    }

    // ---------- Active network ----------
    Rectangle {
        x: 14; y: 54
        width: root.width - 28
        height: 58
        radius: 16
        color: Theme.surfaceSoft
        visible: Network.wifiOn && Network.connected

        Rectangle {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 38; height: 38
            radius: 19
            color: Theme.accent

            Glyph {
                anchors.centerIn: parent
                kind: "wifi"
                level: Network.level
                size: 18
                color: Theme.island
            }
        }

        Column {
            x: 58
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 58 - 100
            spacing: 2

            Text {
                width: parent.width
                text: Network.ssid
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: "Connected · " + (Network.activeSecurity !== "" ? Network.activeSecurity + " · " : "")
                      + Network.strength + "% signal"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 84; height: 28
            radius: 14
            color: discMouse.containsMouse ? Theme.islandHover : Theme.island

            Text {
                anchors.centerIn: parent
                text: "Disconnect"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
            }

            MouseArea {
                id: discMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Network.disconnectActive()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !Network.wifiOn
        text: "Wi-Fi is off"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    // ---------- Reti disponibili ----------
    Item {
        x: 14
        y: Network.connected ? 124 : 60
        width: root.width - 28
        height: root.height - y - 14
        visible: Network.wifiOn

        Text {
            x: 4
            text: "Networks"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 4
            text: "Scanning"
            visible: Network.scanning
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Flickable {
            y: 20
            width: parent.width
            height: parent.height - 20 - (errText.visible ? 20 : 0)
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: parent.width
                spacing: 6

                Repeater {
                    model: Network.others

                    delegate: ListRow {
                        id: row

                        required property var modelData

                        readonly property bool asking: root.asking === modelData.ssid
                        readonly property bool secured: modelData.security !== ""
                        readonly property bool known: Network.known.indexOf(modelData.ssid) >= 0

                        function submit() {
                            Network.connectTo(modelData.ssid, pw.text)
                            root.asking = ""
                        }

                        width: col.width
                        icon: "wifi"
                        iconLevel: Network.levelFor(modelData.signal)
                        title: modelData.ssid
                        subtitle: Network.connecting === modelData.ssid
                                  ? "Connecting…"
                                  : ((known ? "Saved" : (secured ? modelData.security : "Open"))
                                     + " · " + modelData.signal + "%")
                        locked: secured
                        extraHeight: asking ? 48 : 0

                        onClicked: {
                            if (secured && !known) root.asking = asking ? "" : modelData.ssid
                            else Network.connectTo(modelData.ssid, "")
                        }

                        onAskingChanged: {
                            if (asking) {
                                pw.text = ""
                                pw.forceActiveFocus()
                            }
                        }

                        // ----- Password field (in the row's "extra" area) -----
                        Rectangle {
                            x: 10; y: 2
                            width: parent.width - 20 - 82
                            height: 34
                            radius: 17
                            color: Theme.island

                            TextInput {
                                id: pw
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                clip: true
                                onAccepted: row.submit()
                                Keys.onEscapePressed: root.asking = ""
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Password"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                visible: pw.text === ""
                            }
                        }

                        Rectangle {
                            x: parent.width - 82 - 10
                            y: 2
                            width: 82
                            height: 34
                            radius: 17
                            color: Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                color: Theme.island
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: row.submit()
                            }
                        }
                    }
                }
            }
        }

        Text {
            id: errText
            anchors.bottom: parent.bottom
            x: 4
            visible: text !== ""
            text: Network.connectError
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }
}
