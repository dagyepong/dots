import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The Discord panel: a card that drops down under the Discord pill while you
// are in a voice call, the way p3dro's island opens into a call view, drawn
// in the shell's Project SEKAI look.
//
//   +--------------------------------------+
//   | (headset)  VOICE CONNECTED            |   blurple plate (click = open Discord), halftone dots
//   |            # General       3 IN CALL |   and slanted light bands
//   +--------------------------------------+
//   | / (o) You              [mic off]     |   one row per person, each in one
//   | / (o) Miku             ||||          |   of the five attribute colours;
//   | / (o) Rin              [deaf]        |   talking lights the row up
//   +--------------------------------------+
//   |  [ Mute ]        [ Deafen ]          |   keycaps that press into their
//   +--------------------------------------+   shadow, red while on
//
// Same frame as MediaPopup.qml / WeatherPopup.qml (SekaiPopup.qml): the bar
// owns `open`; the frame gives it the focus grab, the placement under the pill,
// and the pop-in / shrink-all-the-way-out animation. Pure UI: Bar.qml feeds it
// DiscordVoiceService.
SekaiPopup {
    id: root

    // The call, fed by Bar.qml.
    property string channelName: ""
    property string backendLabel: ""
    // The server: its name and picture (empty in a DM / group call).
    property string guildName: ""
    property string guildIconUrl: ""
    property var participants: []
    property string selfId: ""
    property bool muted: false
    property bool deafened: false

    // Footer line (what the pill itself does on a click).
    property string hint: "Right-click the pill to deafen · middle-click to mute"

    signal muteRequested()
    signal deafenRequested()
    signal openClientRequested()

    readonly property color blurple: "#5865f2"
    readonly property color danger: "#ed4245"


    // You first, then everyone else by name (so rows never jump while people talk).
    readonly property var members: {
        const list = (root.participants || []).filter(p => p && p.id)
        return list.slice().sort((a, b) => {
            const am = String(a.id) === root.selfId ? 0 : 1
            const bm = String(b.id) === root.selfId ? 0 : 1
            if (am !== bm)
                return am - bm
            return String(a.nick || "").toLowerCase().localeCompare(String(b.nick || "").toLowerCase())
        })
    }

    // Up to five rows show; beyond that the list scrolls.
    readonly property int rowH: 50
    readonly property int rowGap: 6
    readonly property int shown: Math.max(1, Math.min(5, root.members.length))

    // The face on the plate: whoever is talking (not you), else the first other
    // person in the call, else you.
    readonly property var featured: {
        const list = root.members
        const others = list.filter(p => String(p.id) !== root.selfId)
        return others.find(p => p.speaking === true) || others[0] || list[0] || null
    }

    // One of the five SEKAI attribute colours, the same one for the same person.
    function toneFor(id) {
        let h = 0
        const s = String(id || "")
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) >>> 0
        const colors = Theme.attributeColors
        return colors[h % colors.length]
    }

    // The size of the card's face (SekaiPopup draws the outline around it).
    contentWidth: 336
    contentHeight: col.height + 28

    // 0 -> 1 as the card opens: drives the rows' stagger. It is left at 1 on the
    // way out, so the rows stay put while the card shrinks into the pill.
    property real enter: 0

    onOpenChanged: {
        if (open)
            enterAnim.restart()
    }

    NumberAnimation {
        id: enterAnim
        target: root
        property: "enter"
        from: 0
        to: 1
        duration: 340
        easing.type: Easing.OutBack
        easing.overshoot: 1.3
    }

    Column {
        id: col
        x: 16
        y: 14
        width: 304
        spacing: 10

        // ===== the plate =====
        SekaiPlate {
            id: head
            width: col.width
            height: 82 + Theme.shadowOffset
            cornerRadius: 16
            ringWidth: 5
            colorTop: Qt.lighter(root.blurple, 1.16)
            colorBottom: root.blurple
            dotColor: Qt.rgba(1, 1, 1, 0.22)
            bandColor: Qt.rgba(1, 1, 1, 0.10)

            // Who you are talking with: whoever is talking, else the first
            // other person in the call (you, if you are alone), with a live dot.
            Item {
                id: badge
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                height: 46

                readonly property bool talking: root.featured ? root.featured.speaking === true : false

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.textWhite
                    border.width: 2
                    border.color: badge.talking ? Theme.accentMint : Theme.colBorder
                    antialiasing: true
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                }

                ClippingRectangle {
                    anchors.centerIn: parent
                    width: 38
                    height: 38
                    radius: 19
                    color: Qt.lighter(root.blurple, 1.3)

                    // Until the picture arrives (or if there is none): the first letter.
                    Text {
                        anchors.centerIn: parent
                        visible: headImg.status !== Image.Ready
                        text: root.featured ? String(root.featured.nick || root.featured.username || "?").charAt(0).toUpperCase() : "?"
                        color: Theme.textWhite
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }

                    Image {
                        id: headImg
                        anchors.fill: parent
                        source: DiscordVoiceService.avatarUrl(root.featured, 128)
                        sourceSize: Qt.size(76, 76)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }
                }

                // The server's picture, Discord style (a rounded square).
                Item {
                    id: guildTile
                    visible: root.guildIconUrl !== "" || root.guildName !== ""
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: -7
                    anchors.bottomMargin: -7
                    width: 26
                    height: 26

                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: Theme.textWhite
                        border.width: 2
                        border.color: Theme.colBorder
                        antialiasing: true
                    }
                    ClippingRectangle {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: 6
                        color: Qt.lighter(root.blurple, 1.3)

                        Text {
                            anchors.centerIn: parent
                            visible: guildImg.status !== Image.Ready
                            text: root.guildName.charAt(0).toUpperCase()
                            color: Theme.textWhite
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                        Image {
                            id: guildImg
                            anchors.fill: parent
                            source: root.guildIconUrl
                            sourceSize: Qt.size(48, 48)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }
                    }
                }

                // The live dot: a plain circle with the shell's outline (a filled
                // icon glyph came out grainy on this font).
                Rectangle {
                    id: liveDot
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -4
                    anchors.bottomMargin: -4
                    width: 13
                    height: 13
                    radius: 6.5
                    color: Theme.accentMint
                    border.width: 2.5
                    border.color: Theme.line
                    antialiasing: true

                    SequentialAnimation on opacity {
                        running: root.open || root.reveal > 0.001
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
            }

            Column {
                anchors {
                    left: badge.right
                    leftMargin: 14
                    right: countTag.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: -2
                }
                spacing: 1

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "VOICE CONNECTED"
                    color: Qt.rgba(1, 1, 1, 0.78)
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 0.7
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "# " + (root.channelName !== "" ? root.channelName : "Voice channel")
                    color: Theme.textWhite
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                // The server's name under the channel.
                Text {
                    visible: root.guildName !== ""
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.guildName
                    color: Qt.rgba(1, 1, 1, 0.78)
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            // "3 IN CALL" on a slanted plate.
            Item {
                id: countTag
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 12
                width: tagText.implicitWidth + 30
                height: 24

                Slant {
                    anchors.fill: parent
                    skew: 0.22
                    radius: 7
                    color: Theme.textWhite
                    borderColor: Theme.colBorder
                    borderWidth: 3
                }
                Text {
                    id: tagText
                    anchors.centerIn: parent
                    text: root.members.length + " IN CALL"
                    color: root.blurple
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    font.letterSpacing: 0.4
                }
            }

            // The whole plate is one button: bring the Discord window forward.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openClientRequested()
            }
        }

        // ===== the heading =====
        Item {
            width: col.width
            height: 24

            SectionTab {
                text: "In the room"
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.members.length === 1 ? "just you" : root.members.length + " people"
                color: Theme.inkSub
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        // The list sits in a plain Item so the wheel layer (WheelScroll) can be its
        // sibling: inside the Column it would take a slot of its own and the Column
        // refuses its anchors.
        Item {
            width: col.width
            height: root.shown * root.rowH + (root.shown - 1) * root.rowGap

            WheelScroll { scroller: list }
            Flickable {
                id: list
                anchors.fill: parent
                contentWidth: width
                contentHeight: rowsCol.height
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: rowsCol
                    width: parent.width
                    spacing: root.rowGap

                    // An integer model: the delegates stay put (keeping their
                    // pictures and their ring animation) while the list updates.
                    Repeater {
                        model: root.members.length

                        delegate: DiscordMemberRow {
                            required property int index
                            readonly property var who: root.members[index]
                            // Rows slide in one after another as the card opens.
                            readonly property real local: Math.max(0, Math.min(1, root.enter * 1.6 - index * 0.14))

                            width: rowsCol.width
                            user: who
                            isSelf: who ? String(who.id) === root.selfId : false
                            tone: root.toneFor(who ? who.id : "")
                            opacity: local
                            x: (1 - local) * 16
                        }
                    }
                }

                // Nobody else yet.
                Text {
                    visible: root.members.length === 0
                    x: (list.width - width) / 2
                    y: (list.height - height) / 2
                    text: "Waiting for people…"
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMenu
                    font.weight: Font.DemiBold
                }

                SekaiScrollBar {}
            }
        }

        // ===== you: mute / deafen =====
        Row {
            spacing: 10

            DiscordKey {
                width: 147
                icon: root.muted ? "mic_off" : "mic"
                label: root.muted ? "Muted" : "Mute"
                active: root.muted
                activeColor: root.danger
                onClicked: root.muteRequested()
            }
            DiscordKey {
                width: 147
                icon: root.deafened ? "headset_off" : "headphones"
                label: root.deafened ? "Deafened" : "Deafen"
                active: root.deafened
                activeColor: root.danger
                onClicked: root.deafenRequested()
            }
        }

        Text {
            width: col.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.hint
            color: Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            opacity: 0.85
        }
    }
}
