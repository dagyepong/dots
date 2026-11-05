import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.widgets

Item {
    id: root

    property string screenName: ""
    property string status: ""
    property bool failed: false
    property bool checking: false
    property int failCount: 0

    // true: clock on the left and login on the right. Set false to swap them.
    readonly property bool clockLeft: true

    readonly property string user: Quickshell.env("USER")
    property string wallpaper: ""

    signal submit(string password)

    function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1) }

    // Current wallpaper (written by apply-wallpaper.sh)
    FileView {
        id: cur
        path: Quickshell.env("HOME") + "/.cache/quickshell-wallpaper-current"
        blockLoading: true
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Component.onCompleted: {
        try { wallpaper = (cur.text() || "").trim() } catch (e) {}
        input.forceActiveFocus()
    }

    onFailCountChanged: shakeAnim.restart()
    onCheckingChanged: if (!checking) input.forceActiveFocus()

    NumberAnimation on opacity { from: 0; to: 1; duration: 450 }

    // ---------- Sfondo sfocato ----------
    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    Image {
        id: bgImg
        anchors.fill: parent
        visible: false
        source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(1280, 800)
    }

    MultiEffect {
        anchors.fill: parent
        source: bgImg
        visible: bgImg.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
    }

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    // ---------- Ora e data ----------
    Item {
        id: clockArea

        x: root.clockLeft ? root.width * 0.07 : root.width * 0.5
        width: root.width * 0.43
        height: timeText.height + dateText.height + 8
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: timeText
            width: parent.width
            horizontalAlignment: root.clockLeft ? Text.AlignLeft : Text.AlignRight
            text: Qt.formatDateTime(clock.date, Settings.timeFormat)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Math.min(240, root.height * 0.27, clockArea.width / 3.05)
            font.weight: Font.DemiBold
        }

        Text {
            id: dateText
            y: timeText.height + 8
            width: parent.width
            horizontalAlignment: root.clockLeft ? Text.AlignLeft : Text.AlignRight
            text: root.capitalize(Qt.locale("en_US").toString(clock.date, "dddd d MMMM"))
            color: Theme.foreground
            opacity: 0.75
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(18, Math.min(30, root.height * 0.03))
        }
    }

    // ---------- Login: avatar, name, password ----------
    Item {
        id: loginArea

        x: root.clockLeft ? root.width * 0.5 : root.width * 0.07
        width: root.width * 0.43
        height: loginCol.implicitHeight
        anchors.verticalCenter: parent.verticalCenter

        Column {
            id: loginCol
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            spacing: 14

            Item {
                width: parent.width
                height: 120

                ClippingRectangle {
                    anchors.centerIn: parent
                    width: 120
                    height: 120
                    radius: 60
                    color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0.8)
                    border.width: 2
                    border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.25)

                    Image {
                        id: face
                        anchors.fill: parent
                        source: "file://" + Quickshell.env("HOME") + "/.face"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: root.user.charAt(0).toUpperCase()
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 52
                        font.bold: true
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.user
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.bold: true
            }

            Rectangle {
                id: field

                width: parent.width
                height: 48
                radius: 24
                color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0.78)
                border.width: 1.5
                border.color: root.failed ? Theme.danger : (input.activeFocus ? Theme.accent : Theme.border)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                transform: Translate { id: shake }

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    readOnly: root.checking
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    clip: true

                    onAccepted: {
                        if (text !== "") {
                            root.submit(text)
                            text = ""
                        }
                    }

                    Keys.onEscapePressed: text = ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: input.text === ""
                    text: root.checking ? "Checking…" : "Password"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }
            }

            Text {
                width: parent.width
                height: 16
                horizontalAlignment: Text.AlignHCenter
                text: root.status
                color: Theme.danger
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }

    // Wrong password: the field shakes
    SequentialAnimation {
        id: shakeAnim

        NumberAnimation { target: shake; property: "x"; to: -14; duration: 55 }
        NumberAnimation { target: shake; property: "x"; to: 14; duration: 90 }
        NumberAnimation { target: shake; property: "x"; to: -9; duration: 75 }
        NumberAnimation { target: shake; property: "x"; to: 9; duration: 75 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 55 }
    }

    // ---------- Top right: Wi-Fi and battery (symbol only), side by side ----------
    Row {
        anchors.top: parent.top
        anchors.topMargin: 28
        anchors.right: parent.right
        anchors.rightMargin: 32
        spacing: 8

        Rectangle {
            width: wifiRow.implicitWidth + 28
            height: 38
            radius: 19
            color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0.7)
            border.width: 1
            border.color: Theme.border

            Row {
                id: wifiRow
                anchors.centerIn: parent
                spacing: 8

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "wifi"
                    level: Network.level
                    size: 16
                    color: Network.wifiOn ? (Network.connected ? Theme.accent : Theme.foreground) : Theme.muted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Network.connected ? Network.ssid : (Network.wifiOn ? "Not connected" : "Wi-Fi is off")
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }

        Rectangle {
            visible: Battery.present
            width: 54
            height: 38
            radius: 19
            color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0.7)
            border.width: 1
            border.color: Battery.low ? Theme.danger : Theme.border

            BatteryIcon {
                anchors.centerIn: parent
                percent: Battery.percent
                charging: Battery.charging
                outline: Battery.tone
                fillColor: Battery.tone
            }
        }
    }

    // ---------- Notifications: they arrive even on a locked screen ----------
    Rectangle {
        id: notif

        readonly property bool shownHere: Toast.active
            && (Toast.screen === "" || Toast.screen === root.screenName)

        anchors.horizontalCenter: parent.horizontalCenter
        y: shownHere ? 28 : -height - 24
        width: 380
        height: toastView.implicitHeight
        radius: 24
        color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0.88)
        border.width: 1
        border.color: (Toast.current && Toast.current.tone === "danger") ? Theme.danger : Theme.border
        opacity: shownHere ? 1 : 0
        clip: true

        Behavior on y       { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        ToastView {
            id: toastView
            width: parent.width
            height: implicitHeight
        }
    }

    // ---------- Safe test banner ----------
    Text {
        visible: UiState.lockTest
        x: 32
        y: 32
        text: "TEST: unlocks itself in " + UiState.lockTestLeft + " s"
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
    }
}
