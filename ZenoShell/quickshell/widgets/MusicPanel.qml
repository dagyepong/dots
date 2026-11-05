import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.services

// Panel: music (blurred cover as background), controls, progress and spectrum
Item {
    id: root

    width: 300
    height: 392

    ClippingRectangle {
        x: 10; y: 10
        width: parent.width - 20
        height: parent.height - 20
        radius: 22
        color: Theme.surfaceSoft

        Image {
            id: blurSrc
            anchors.fill: parent
            source: Media.artUrl
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(96, 96)
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: blurSrc
            visible: Media.active && Media.artUrl !== ""
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.3
        }

        Rectangle {
            anchors.fill: parent
            visible: Media.active && Media.artUrl !== ""
            color: Theme.scrim
        }

        // The record
        Rectangle {
            x: (parent.width - width) / 2
            y: 22
            width: 150; height: 150
            radius: 75
            color: Theme.island
            border.width: 3
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)

            ClippingRectangle {
                anchors.centerIn: parent
                width: parent.width - 14
                height: width
                radius: width / 2
                color: Theme.accent

                Image {
                    anchors.fill: parent
                    source: Media.artUrl
                    visible: Media.active && Media.artUrl !== ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(300, 300)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 18; height: 18
                    radius: 9
                    color: Theme.island
                    opacity: 0.9
                }
            }

            RotationAnimator on rotation {
                from: 0; to: 360
                duration: 14000
                loops: Animation.Infinite
                running: Media.playing && root.visible
            }
        }

        Text {
            x: 14; y: 184
            width: parent.width - 28
            horizontalAlignment: Text.AlignHCenter
            text: Media.active ? (Media.title || "No title") : "Nothing Playing"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            x: 14; y: 206
            width: parent.width - 28
            horizontalAlignment: Text.AlignHCenter
            text: Media.active ? Media.artist : "Enjoy the silence"
            color: Theme.foreground
            opacity: 0.7
            font.family: Theme.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Spectrum {
            x: (parent.width - width) / 2
            y: 230
            width: 70; height: 26
            visible: Media.active && Media.playing
        }

        Row {
            y: 266
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            MediaButton { kind: "prev"; enabled: Media.canPrevious; onClicked: Media.previous() }
            MediaButton { kind: Media.playing ? "pause" : "play"; highlighted: true; enabled: Media.canToggle; onClicked: Media.toggle() }
            MediaButton { kind: "next"; enabled: Media.canNext; onClicked: Media.next() }
        }

        // Progress (click = seek)
        Item {
            x: 18; y: 312
            width: parent.width - 36
            height: 12

            Rectangle {
                id: seekTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.25)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: seekTrack.width * Media.progress
                height: 4
                radius: 2
                color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                enabled: Media.canSeek
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => Media.seekTo(mouse.x / width)
            }
        }

        Text {
            x: 18; y: 330
            text: Media.active ? Media.fmt(Media.position) : "--:--"
            color: Theme.foreground
            opacity: 0.6
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 330
            text: Media.active ? Media.fmt(Media.length) : "--:--"
            color: Theme.foreground
            opacity: 0.6
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
