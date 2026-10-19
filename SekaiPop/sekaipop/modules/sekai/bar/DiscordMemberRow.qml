import Quickshell.Widgets
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// One person in the Discord panel (DiscordPopup.qml): a slanted tab in their
// own colour, avatar in the shell's ring, name, a line saying what they are
// doing, and on the right either rhythm-game style bars while they talk or a
// red badge while they are muted / deafened.
//
// Everyone gets one of the five Project SEKAI attribute colours, picked from
// their Discord id so it is the same every time. Talking lights the row's
// outline in that colour and sends a ring out from the avatar.
Rectangle {
    id: row

    property var user: null
    property bool isSelf: false
    // Their colour (set by the panel from the id).
    property color tone: Theme.accentCyan

    readonly property bool talking: user ? user.speaking === true : false
    readonly property bool deaf: user ? user.deaf === true : false
    readonly property bool mute: user ? user.mute === true : false
    readonly property bool silenced: deaf || mute

    readonly property string nameText: user ? String(user.nick || user.username || "?") : "?"
    readonly property string stateText: {
        const parts = []
        if (row.isSelf)
            parts.push("You")
        if (row.deaf)
            parts.push("Deafened")
        else if (row.mute)
            parts.push("Muted")
        else if (row.talking)
            parts.push("Talking")
        return parts.length > 0 ? parts.join(" · ") : "In call"
    }

    implicitWidth: 304
    implicitHeight: 50
    radius: 14
    color: row.talking ? Theme.surfaceTint : Theme.surfaceHover
    border.width: 2
    border.color: row.talking ? row.tone : Theme.line
    antialiasing: true

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    // ===== the slanted tab =====
    // A pair of slashes (the menus' "//" motif) in the person's colour: one
    // bold, one thin and dimmer. A lone slash read as a stray character.
    Slant {
        x: 7
        y: 9
        width: 13
        height: row.height - 18
        skew: 0.3
        radius: 3
        color: row.tone
    }
    Slant {
        x: 21
        y: 9
        width: 8
        height: row.height - 18
        skew: 0.3
        radius: 2
        color: row.tone
        opacity: 0.5
    }

    // ===== avatar =====
    Item {
        id: avatar
        x: 34
        y: (row.height - height) / 2
        width: 36
        height: 36

        // The ring that leaves the avatar while this person talks.
        Rectangle {
            id: halo
            anchors.centerIn: parent
            width: 36
            height: 36
            radius: 18
            color: "transparent"
            border.width: 3
            border.color: row.tone
            visible: row.talking
            opacity: 0

            ParallelAnimation {
                running: row.talking
                loops: Animation.Infinite
                NumberAnimation {
                    target: halo
                    property: "scale"
                    from: 1
                    to: 1.5
                    duration: 900
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: halo
                    property: "opacity"
                    from: 0.85
                    to: 0
                    duration: 900
                    easing.type: Easing.OutCubic
                }
            }
        }

        // The white ring + navy outline, the same two layers a Pill has.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.ringWhite
            border.width: 2
            border.color: row.talking ? row.tone : Theme.line
            antialiasing: true
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }

        ClippingRectangle {
            anchors.centerIn: parent
            width: 28
            height: 28
            radius: 14
            color: row.tone

            // Until the picture arrives (or if there is none): the first letter.
            Text {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                text: row.nameText.charAt(0).toUpperCase()
                color: Theme.colBorder
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Image {
                id: img
                anchors.fill: parent
                source: DiscordVoiceService.avatarUrl(row.user, 64)
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                opacity: row.silenced ? 0.6 : 1
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }
        }
    }

    // ===== who and what =====
    Column {
        anchors {
            left: avatar.right
            leftMargin: 10
            right: parent.right
            rightMargin: 52
            verticalCenter: parent.verticalCenter
        }
        spacing: 1

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: row.nameText
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMenu
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: row.stateText
            color: Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: row.talking ? Font.Bold : Font.Normal
        }
    }

    // ===== talking: rhythm-game bars in their colour =====
    Row {
        id: bars
        visible: row.talking && !row.silenced
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        spacing: 3

        Repeater {
            model: 4

            delegate: Rectangle {
                id: bar
                required property int index
                property real level: 6
                width: 5
                height: bar.level
                y: (bars.height - bar.level) / 2
                radius: 2.5
                color: row.tone
                border.width: 1.5
                border.color: Theme.line
                antialiasing: true

                // Each bar bounces on its own beat, so the four never move together.
                SequentialAnimation on level {
                    running: bars.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 22 - bar.index * 3; duration: 210 + bar.index * 60; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 6 + bar.index * 2; duration: 260 + bar.index * 50; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ===== muted / deafened =====
    MaterialIcon {
        visible: row.silenced
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        name: row.deaf ? "headset_off" : "mic_off"
        fill: 0
        size: 22
        color: "#ed4245"
    }
}
