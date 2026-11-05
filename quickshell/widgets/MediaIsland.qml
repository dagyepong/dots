import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.services

Rectangle {
    id: root

    signal launcherRequested()

    property bool expanded: false
    readonly property bool showCard: expanded && Media.active
    readonly property bool hovered: hover.hovered

    readonly property int cardW: 340
    readonly property int cardH: 160
    readonly property int frame: 6      // thickness of the black frame

    width:  showCard ? cardW : Theme.islandHeight
    height: showCard ? cardH : Theme.islandHeight
    radius: Math.min(26, height / 2)
    color: (!showCard && hovered) ? Theme.islandHover : Theme.island
    border.width: 1
    border.color: Theme.border
    clip: true

    Behavior on width  { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on color  { ColorAnimation { duration: 120 } }

    // Keeps the progress bar updated while the card is open
    onShowCardChanged: if (showCard && Media.player) Media.player.positionChanged()

    FrameAnimation {
        running: root.showCard && Media.playing
        onTriggered: if (Media.player) Media.player.positionChanged()
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered && Media.active) {
                collapseTimer.stop()
                root.expanded = true
            } else if (!hovered) {
                collapseTimer.restart()
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 250
        onTriggered: root.expanded = false
    }

    // Without a player the circle is the (future) launcher
    MouseArea {
        anchors.fill: parent
        enabled: !Media.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.launcherRequested()
    }

    // ---------- Background: blurred cover inside the black frame ----------
    ClippingRectangle {
        id: bg

        anchors.fill: parent
        anchors.margins: root.frame
        radius: Math.max(0, root.radius - root.frame)
        color: "transparent"

        opacity: root.showCard ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.showCard ? 240 : 100 } }

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
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.3
        }

        // Darkens so the text is easy to read
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
        }
    }

    // ---------- Dotted icon (no active player) ----------
    Grid {
        x: (Theme.islandHeight - width) / 2
        y: (Theme.islandHeight - height) / 2
        columns: 2
        spacing: 3
        visible: !Media.active

        Repeater {
            model: 4
            Rectangle {
                width: 5
                height: 5
                radius: 2.5
                color: Theme.foreground
            }
        }
    }

    // ---------- Copertina: da cerchietto a quadrato arrotondato ----------
    ClippingRectangle {
        id: cover

        x: root.showCard ? 20 : 3
        y: root.showCard ? 18 : 3
        width: root.showCard ? 84 : Theme.islandHeight - 6
        height: width
        radius: 14
        color: Theme.surfaceSoft
        visible: Media.active

        Behavior on x     { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y     { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Image {
            anchors.fill: parent
            source: Media.artUrl
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(256, 256)
        }
    }

    // ---------- Colonna destra ----------
    Item {
        id: info

        x: 120
        y: 18
        width: root.cardW - 120 - 20
        height: 132

        opacity: root.showCard ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.showCard ? 220 : 80 } }

        Text {
            y: 0
            width: parent.width
            text: Media.title || "No title"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            y: 25
            width: parent.width
            text: Media.artist
            color: Theme.foreground
            opacity: 0.85
            font.family: Theme.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            y: 42
            width: parent.width
            text: Media.album
            color: Theme.foreground
            opacity: 0.55
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Text {
            y: 56
            width: parent.width
            text: Media.source
            color: Theme.foreground
            opacity: 0.55
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        // Progress bar (clickable to seek in the track)
        Item {
            id: seek

            y: 76
            width: parent.width
            height: 12

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.25)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: track.width * Media.progress
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

        // Times under the bar: elapsed on the left, duration on the right
        Item {
            y: 90
            width: parent.width
            height: 12

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Media.fmt(Media.position)
                color: Theme.foreground
                opacity: 0.6
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Media.fmt(Media.length)
                color: Theme.foreground
                opacity: 0.6
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        // Controlli
        Row {
            y: 106
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            MediaButton {
                kind: "prev"
                enabled: Media.canPrevious
                onClicked: Media.previous()
            }

            MediaButton {
                kind: Media.playing ? "pause" : "play"
                highlighted: true
                enabled: Media.canToggle
                onClicked: Media.toggle()
            }

            MediaButton {
                kind: "next"
                enabled: Media.canNext
                onClicked: Media.next()
            }
        }
    }
}
