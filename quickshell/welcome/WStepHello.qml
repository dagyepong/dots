import QtQuick
import qs.theme
import qs.services
import qs.widgets

// Step 1: hero
Item {
    id: root

    // The logo: concentric rings that breathe
    Item {
        id: logo
        anchors.horizontalCenter: parent.horizontalCenter
        y: 70
        width: 150
        height: 150

        Repeater {
            model: 3
            delegate: Rectangle {
                required property int index
                anchors.centerIn: parent
                width: 150 - index * 34
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                opacity: 0.85 - index * 0.25

                SequentialAnimation on scale {
                    running: true
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 260 }
                    NumberAnimation { to: 1.07; duration: 1300; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1300; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: (2 - index) * 260 }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 50; height: 50; radius: 25
            color: Theme.accent
            Glyph { anchors.centerIn: parent; kind: "star"; level: 2; size: 24; color: Theme.island }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 250
        text: "Welcome to ZenoShell"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 40
        font.bold: true
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 306
        width: Math.min(640, parent.width - 120)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "A few quick steps to make it yours: how it looks, the colors, the clock, the network, and the keys you will use every day. You can change everything later, and see this tour again from Settings."
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 15
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 400
        spacing: 14

        Repeater {
            model: [
                { icon: "grid",  t: "4 styles",              d: "Island, Classic, Dashboard, Vertical" },
                { icon: "star",  t: "Colors from wallpaper", d: "Light or dark, 10 themes" },
                { icon: "gear",  t: "Same keys everywhere",  d: "niri and Hyprland" }
            ]

            delegate: Rectangle {
                required property var modelData
                width: 230; height: 84; radius: 18
                color: Theme.surfaceSoft

                Rectangle {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 38; height: 38; radius: 19
                    color: Theme.island
                    Glyph { anchors.centerIn: parent; kind: modelData.icon; level: 2; size: 17; color: Theme.accent }
                }

                Column {
                    x: 64
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 76
                    spacing: 3
                    Text { width: parent.width; text: modelData.t; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                    Text { width: parent.width; text: modelData.d; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 11; wrapMode: Text.WordWrap }
                }
            }
        }
    }
}
