import QtQuick
import QtQuick.Effects
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The Discord pill: appears on the bar while you are in a Discord voice
// channel, the way p3dro's island shows a call. Pure UI: Bar.qml feeds it
// DiscordVoiceService's state.
//
//   [ (o)(o)(o)  General · 3  (mic off) ]
//
// Up to three avatars of whoever is in the call, a ring lights around the
// ones who are talking; then the channel and the head count, and a red badge
// while you are muted or deafened (a plain mic / headset glyph). Left-click opens the Discord panel
// (DiscordPopup.qml: who is in the call, mute / deafen keys, open Discord);
// middle-click mutes / unmutes you, right-click deafens / undeafens. Hover for
// a short list of who is in the call. (Settings -> Bar -> Discord pill click
// makes a left click mute again.)
//
// The first time (Discord has to be linked once) the pill shows "Link
// Discord" instead: click it, and accept the prompt in Discord.
//
// It grows in and shrinks away (`reveal`, 0 -> 1) like the privacy pill: the
// pill scales and fades while its slot in the bar opens or closes (Status_Bar
// reads `reveal`). Nothing is drawn while there is no call: the module takes
// no room (`visible` is false once it has finished shrinking).
Item {
    id: root

    property bool vertical: false
    // Which edge the bar is on, so the tag opens towards the screen.
    property string barPosition: "top"
    // False while the module is switched off in Settings -> Bar.
    property bool allowed: true

    // The state, fed by Bar.qml.
    property bool inCall: false
    property bool needsAuth: false
    property bool authorizing: false
    property string channelName: ""
    property var participants: []
    property bool muted: false
    property bool deafened: false

    // Left click opens the panel (false: it mutes, as before).
    property bool leftOpensPanel: true
    // The panel is open: the pill stays pressed in, and the hover tag keeps quiet.
    property bool panelOpen: false

    signal muteRequested()
    signal deafenRequested()
    signal authorizeRequested()
    signal panelRequested()

    readonly property color blurple: "#5865f2"
    readonly property color danger: "#ed4245"

    readonly property bool live: allowed && (inCall || needsAuth)

    // 0 -> 1. Also what the bar's layout uses to open and close this module's
    // slot gradually (see Status_Bar.qml).
    property real reveal: live ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    visible: reveal > 0.001
    opacity: Math.min(1, reveal * 1.5)
    scale: 0.55 + 0.45 * reveal

    // What the pill shows follows the call while it is on, and stays as it
    // was while the pill shrinks away (the call is already over by then,
    // which would empty it mid-fade).
    property var shownParticipants: []
    property string shownChannel: ""
    property bool shownAuth: false
    // (These look at the inputs, not at `live`: when a handler runs, `live`
    // may not have caught up with the change yet, which would leave the pill
    // showing the wrong face.)
    function refreshShown() {
        if (inCall) {
            shownParticipants = participants
            shownChannel = channelName
            shownAuth = false
        } else if (needsAuth) {
            shownAuth = true
        }
    }
    onParticipantsChanged: refreshShown()
    onChannelNameChanged: refreshShown()
    onNeedsAuthChanged: refreshShown()
    onInCallChanged: refreshShown()
    Component.onCompleted: refreshShown()

    readonly property int avatarCount: Math.min(3, shownParticipants.length)
    // On the flat bar the pill's coloured band is only 20 px tall (36 - 2 * the 8 px
    // ring), so a 24 px avatar stuck out above and below it and looked off-centre;
    // there it is 20 px. The standing bar has room for 24.
    readonly property int avatarSize: root.vertical ? 24 : 20
    readonly property int avatarStep: root.vertical ? 16 : 13
    readonly property real stackWidth: avatarCount > 0
        ? avatarSize + (avatarCount - 1) * avatarStep + 4 : avatarSize

    readonly property string countText: shownParticipants.length === 1 ? "1" : String(shownParticipants.length)
    readonly property string labelText: shownAuth
        ? (authorizing ? "Waiting for Discord…" : "Link Discord")
        : (shownChannel !== "" ? shownChannel : "Voice") + " · " + countText

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    // One mask for every avatar: they are all the same circle.
    Rectangle {
        id: avatarMask
        width: root.avatarSize - 4
        height: width
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: Theme.radiusBadge
        ringWidth: vertical ? 6 : 8
        capKeepsFill: true   // Capsule bar: the blurple is the state, keep it
        fillColor: root.blurple
        pressed: area.pressed || (root.panelOpen && !root.shownAuth)

        implicitWidth: root.vertical ? pill.barVWidth
                                     : row.implicitWidth + 2 * ringWidth + 14
        implicitHeight: root.vertical ? col.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 12 + Theme.shadowOffset
                                      : Theme.pillHeight + Theme.shadowOffset

        // ===== flat bar =====
        Row {
            id: row
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: 7

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: root.shownAuth ? glyphComp : stackComp
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 150)
                text: root.labelText
                elide: Text.ElideRight
                color: Theme.textWhite
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                active: !root.shownAuth
                visible: active
                sourceComponent: badgeComp
            }
        }

        // ===== standing bar: the same, stacked =====
        Column {
            id: col
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 4

            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: root.shownAuth ? glyphComp : (root.avatarCount > 0 ? soloComp : glyphComp)
            }

            Text {
                visible: !root.shownAuth
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.countText
                color: Theme.textWhite
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                active: !root.shownAuth
                visible: active
                sourceComponent: badgeComp
            }
        }
    }

    // The headset glyph: no avatars to show (not linked yet, or empty).
    Component {
        id: glyphComp
        MaterialIcon {
            name: "headset"
            size: 18
            color: Theme.textWhite
        }
    }

    // Overlapping avatars of the first three people in the call, a ring
    // around whoever is talking.
    Component {
        id: stackComp
        Item {
            width: root.stackWidth
            height: root.avatarSize

            // An integer model, so the delegates stay put (and keep their
            // pictures and their ring animation) while the list updates.
            Repeater {
                model: root.avatarCount

                delegate: Avatar {
                    required property int index
                    user: root.shownParticipants[index]
                    base: root.blurple
                    diameter: root.avatarSize
                    mask: avatarMask
                    x: index * root.avatarStep
                    z: index
                }
            }
        }
    }

    // One avatar, for the standing bar: whoever is talking, else the first.
    Component {
        id: soloComp
        Item {
            width: root.avatarSize
            height: root.avatarSize
            readonly property var who: {
                const list = root.shownParticipants
                const talker = list.find(p => p && p.speaking === true)
                return talker || list[0]
            }
            Avatar {
                user: parent.who
                base: root.blurple
                diameter: root.avatarSize
                mask: avatarMask
            }
        }
    }

    // Your mic, as a plain glyph like the other pills: mic, mic_off while muted, headset_off while deafened.
    Component {
        id: badgeComp
        MaterialIcon {
            name: root.deafened ? "headset_off" : (root.muted ? "mic_off" : "mic")
            size: 18
            color: Theme.textWhite
            opacity: root.muted || root.deafened ? 1 : 0.8
        }
    }

    // One avatar in a ring: lit white while this person is talking, the
    // pill's own colour otherwise (so it reads as a gap between neighbours).
    // (An inline component does not see this file's ids, so everything it
    // needs comes in as a property.)
    component Avatar: Item {
        id: av
        property var user: null
        property color base: "#5865f2"
        property real diameter: 24
        property Item mask: null
        readonly property bool talking: user ? user.speaking === true : false
        width: diameter
        height: diameter

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: av.base
            border.width: 2
            border.color: av.talking ? Theme.textWhite : av.base
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        // Until the picture arrives (or if there is none): the first letter.
        Rectangle {
            anchors.centerIn: parent
            width: av.diameter - 4
            height: width
            radius: width / 2
            color: Qt.lighter(av.base, 1.3)
            visible: img.status !== Image.Ready
            Text {
                anchors.centerIn: parent
                text: av.user ? String(av.user.nick || "?").charAt(0).toUpperCase() : "?"
                color: Theme.textWhite
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        Image {
            id: img
            anchors.centerIn: parent
            width: av.diameter - 4
            height: width
            source: DiscordVoiceService.avatarUrl(av.user, 64)
            sourceSize: Qt.size(48, 48)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: img
            source: img
            visible: img.status === Image.Ready
            maskEnabled: av.mask !== null
            maskSource: av.mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    // Left: mute (or link Discord, the first time). Right: deafen. Hover:
    // who is in the call, as a small tag towards the inside of the screen.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (root.shownAuth)
                root.authorizeRequested()
            else if (mouse.button === Qt.RightButton)
                root.deafenRequested()
            else if (mouse.button === Qt.MiddleButton)
                root.muteRequested()
            else if (root.leftOpensPanel)
                root.panelRequested()
            else
                root.muteRequested()
        }
    }

    readonly property string tipText: {
        if (root.shownAuth)
            return root.authorizing ? "Accept the request in Discord" : "Link Discord once to see your calls here"
        const lines = [(root.shownChannel !== "" ? root.shownChannel : "Voice channel")
            + " — " + root.shownParticipants.length + " in call"]
        for (const p of root.shownParticipants.slice(0, 8)) {
            if (!p)
                continue
            const state = p.deaf === true ? " (deafened)" : (p.mute === true ? " (muted)" : "")
            lines.push((p.speaking === true ? "● " : "   ") + (p.nick || "?") + state)
        }
        if (root.shownParticipants.length > 8)
            lines.push("   +" + (root.shownParticipants.length - 8) + " more")
        const muteWord = root.muted ? "unmute" : "mute"
        const deafWord = root.deafened ? "undeafen" : "deafen"
        lines.push(root.leftOpensPanel
            ? "Click: open · Middle: " + muteWord + " · Right: " + deafWord
            : "Click: " + muteWord + " · Right-click: " + deafWord)
        return lines.join("\n")
    }

    BarTip {
        shown: area.containsMouse && !root.panelOpen
        text: root.tipText
        barPosition: root.barPosition
    }
}
