import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The lyrics source picker: where the words of the song come from, and what each place
// found for the song that is on now.
//
//   Auto        the best provider for each song (word by word over synced, then the one
//               cut to the song's length). This is the way it starts.
//   a provider  use that one whenever it has the song (the best of the others when it does
//               not). Each row says what it found: WORD BY WORD, SYNCED, Not found, or
//               Unreachable (a click on "Try again" asks them all again). The rows are in the
//               order the providers are liked: Boidu first (see LyricsService.providers).
//               The same choice is in Settings -> Desktop, under the Lyrics switch.
//
// Opened by the "sources" key that appears when you point at the lyrics (LyricsWidget.qml)
// or `qs -c sekaipop ipc call lyrics picker`. It is the same card as the desktop's
// right-click menu (DesktopMenu.qml) in a full-screen transparent Overlay window that
// exists only while it is open, so a click anywhere else (or Esc) closes it. The service
// side is services/LyricsService.qml (`preferred`, `sourceStates`, `providers`).
PanelWindow {
    id: win

    readonly property string wantedScreen: LyricsService.pickerScreen
    screen: Quickshell.screens.find(s => s.name === win.wantedScreen) ?? Quickshell.screens[0]

    readonly property real uiScale: ShellScale.forScreen(win.screen)
    readonly property real roomW: win.width / win.uiScale
    readonly property real roomH: win.height / win.uiScale

    visible: LyricsService.pickerOpen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sekaipop-lyrics-sources"
    WlrLayershell.keyboardFocus: LyricsService.pickerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Click anywhere outside the card: close.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: LyricsService.closePicker()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: LyricsService.closePicker()
    }

    Component.onCompleted: card.pop()

    onVisibleChanged: {
        if (win.visible)
            card.pop()
    }

    // One line of the list: a round radio, the name, and on the right what it found.
    component SourceRow: Item {
        id: row

        property string name: ""
        property string note: ""          // under the name, small
        property string kind: ""          // "word" | "synced" | "loading" | "none" | "offline" | ""
        property bool selected: false
        property bool inUse: false
        signal picked
        signal retry

        readonly property bool dim: row.kind === "none"

        height: 40

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            radius: 9
            color: Theme.surfaceHover
            opacity: area.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 110 }
            }
        }

        // the radio
        Rectangle {
            id: radio
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            color: "transparent"
            border.width: 2
            border.color: row.selected ? Theme.accentCyan : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, row.dim ? 0.28 : 0.5)

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: Theme.accentCyan
                scale: row.selected ? 1 : 0
                opacity: row.selected ? 1 : 0

                Behavior on scale {
                    NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 100 }
                }
            }
        }

        Column {
            anchors.left: radio.right
            anchors.leftMargin: 12
            anchors.right: status.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: row.name
                elide: Text.ElideRight
                color: Theme.ink
                opacity: row.dim ? 0.45 : 1
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: row.inUse ? Font.ExtraBold : Font.DemiBold
                font.styleName: row.inUse ? Theme.fontStyleBold : ""
            }

            Text {
                visible: row.note !== ""
                width: parent.width
                text: row.note
                elide: Text.ElideRight
                color: Theme.inkSub
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        // what it found
        Row {
            id: status
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                visible: row.kind === "offline"
                anchors.verticalCenter: parent.verticalCenter
                text: "Unreachable"
                color: Theme.inkSub
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                visible: row.kind === "offline"
                anchors.verticalCenter: parent.verticalCenter
                text: "Try again"
                color: Theme.accentCyan
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.underline: retryArea.containsMouse

                MouseArea {
                    id: retryArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.retry()
                }
            }

            Text {
                visible: row.kind === "none"
                anchors.verticalCenter: parent.verticalCenter
                text: "Not found"
                color: Theme.inkSub
                opacity: 0.7
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                visible: row.kind === "loading"
                anchors.verticalCenter: parent.verticalCenter
                text: "asking..."
                color: Theme.inkSub
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Rectangle {
                visible: row.kind === "word" || row.kind === "synced"
                anchors.verticalCenter: parent.verticalCenter
                width: badge.implicitWidth + 16
                height: 22
                radius: 11
                color: row.kind === "word"
                    ? Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, 0.2)
                    : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.12)

                Text {
                    id: badge
                    anchors.centerIn: parent
                    text: row.kind === "word" ? "WORD BY WORD" : "SYNCED"
                    color: row.kind === "word" ? Theme.accentCyan : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.8
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: row.picked()
        }
    }

    ScaleHost {
        anchors.fill: parent
        factor: win.uiScale

        Pill {
            id: card

            readonly property real innerWidth: 360
            readonly property real wantX: LyricsService.pickerX < 0 ? win.roomW / 2 : LyricsService.pickerX
            readonly property real wantY: LyricsService.pickerY < 0 ? (win.roomH - card.height) / 2 : LyricsService.pickerY + 6

            // Centred under the lyrics (or on the screen), pushed back in when it would
            // hang off.
            x: Math.max(8, Math.min(card.wantX - card.width / 2, win.roomW - card.width - 8))
            y: Math.max(8, Math.min(card.wantY, win.roomH - card.height - 8))

            cornerRadius: Theme.radiusOuter
            ringWidth: Theme.borderWidth
            innerRing: Theme.cardRing
            fillColor: Theme.surface
            implicitWidth: card.innerWidth + 10 + card.ringWidth * 2
            implicitHeight: col.implicitHeight + 10 + card.ringWidth * 2 + Theme.shadowOffset
            width: implicitWidth
            height: implicitHeight

            property real popProgress: 1

            function pop() {
                popAnim.restart()
            }

            SequentialAnimation {
                id: popAnim
                ScriptAction { script: card.popProgress = 0 }
                PauseAnimation { duration: 40 }
                NumberAnimation {
                    target: card
                    property: "popProgress"
                    from: 0
                    to: 1
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }

            opacity: Math.min(1, card.popProgress * 3)
            transform: Scale {
                origin.x: card.width / 2
                origin.y: 0
                xScale: 0.86 + 0.14 * card.popProgress
                yScale: 0.86 + 0.14 * card.popProgress
            }

            // Takes the clicks that land on the card, so they do not close it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            }

            Column {
                id: col
                x: 5
                y: 5
                width: card.innerWidth

                Text {
                    x: 12
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    text: "Lyrics source"
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.6
                    font.capitalization: Font.AllUppercase
                }

                SourceRow {
                    width: col.width
                    name: "Auto"
                    note: LyricsService.source !== "" && LyricsService.status === "ready"
                        ? "using " + LyricsService.providerName(LyricsService.source)
                        : "the best one for each song"
                    selected: LyricsService.preferred === "auto"
                    onPicked: LyricsService.setPreferred("auto")
                }

                Repeater {
                    model: LyricsService.providers

                    delegate: SourceRow {
                        id: line

                        required property var modelData

                        width: col.width
                        name: line.modelData.name
                        note: line.modelData.hint
                        selected: LyricsService.preferred === line.modelData.id
                        inUse: LyricsService.source === line.modelData.id && LyricsService.status === "ready"
                        kind: {
                            const s = LyricsService.sourceStates[line.modelData.id]
                            if (s !== undefined)
                                return s
                            // from the cache: only the one that was used is known
                            return LyricsService.source === line.modelData.id ? LyricsService.sourceKind : ""
                        }
                        onPicked: LyricsService.setPreferred(line.modelData.id)
                        onRetry: LyricsService.refresh()
                    }
                }
            }
        }
    }
}
