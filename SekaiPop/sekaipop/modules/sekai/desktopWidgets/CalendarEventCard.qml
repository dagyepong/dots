import QtQuick
import "../bar/CalendarMath.js" as CM
import "../../common/functions/EventMath.js" as EM
import qs.modules.common
import qs.modules.common.widgets

// One entry on the calendar card (CalendarCardWidget.qml) as a Project SEKAI style
// banner: a slanted block in the entry's colour with its day, the title, the time and
// note, and a chip that counts down ("in 3 days", "Due tomorrow", "2 days late",
// "Done"). Click it to open it: the full date, the whole note and the buttons (Done /
// Undo for a deadline, Edit, Delete). It is a ListView delegate: it takes its width
// from the list, and its height grows when it is opened.
//
// It knows nothing about the widget around it; everything comes in as a property and
// everything it wants done goes out as a signal:
//
//   CalendarEventCard {
//       today: win.today
//       expanded: win.expandedId === modelData.id
//       onToggled: ...
//       onEditRequested: ...
//   }
Item {
    id: ec

    // The entry (a ListView over an array hands it over as `modelData`).
    required property var modelData
    readonly property var ev: ec.modelData

    property date today: new Date()
    property bool expanded: false
    property bool use24h: false

    // The widget's alert colours (a late or near deadline), so there is one source.
    property color alertInk: "#e0575b"
    property color alertText: "#ffffff"
    property color soonInk: "#f0a030"

    signal toggled()
    signal doneToggled()
    signal editRequested()
    signal deleteRequested()

    readonly property var pdate: EM.parseDate(ec.ev.date)
    readonly property int diff: EM.diffTo(ec.today, ec.ev.date)
    readonly property string st: EM.dueState(ec.ev, ec.diff)
    readonly property bool deadline: ec.ev.kind === "deadline"
    readonly property bool done: ec.st === "done"
    readonly property color accent: Qt.color(Theme.attributeColors[Math.max(0, Math.min(Theme.attributeColors.length - 1, ec.ev.color))])
    readonly property real face: 56

    readonly property bool hot: ec.st === "overdue" || ec.st === "today"
    readonly property color stateInk: ec.hot ? ec.alertInk : (ec.st === "soon" ? ec.soonInk : Theme.pInkSub)

    // The chip's words: a deadline that is still ahead reads "Due ...".
    readonly property string chipText: {
        const w = EM.countdown(ec.ev, ec.diff)
        if (ec.deadline && !ec.done && ec.diff >= 0)
            return "Due " + w.charAt(0).toLowerCase() + w.slice(1)
        return w
    }

    // The accent washed over the surface (the event's own colour, softened).
    readonly property color accentWash: Qt.tint(Theme.pSurface, Qt.rgba(ec.accent.r, ec.accent.g, ec.accent.b, 0.62))
    readonly property color chipFill: ec.hot ? ec.alertInk
        : (ec.st === "soon" ? ec.soonInk : (ec.done ? Theme.pSurfaceHover : ec.accentWash))
    readonly property color chipInk: ec.hot ? ec.alertText
        : (ec.st === "soon" ? Theme.colBorder : (ec.done ? Theme.pInkSub : Theme.pInk))

    readonly property string weekdayText: ec.pdate
        ? CM.weekdayShort(new Date(ec.pdate.y, ec.pdate.m, ec.pdate.d).getDay()) : ""

    width: ListView.view ? ListView.view.width : 0
    height: ec.face + (ec.expanded ? detail.height + 8 : 0)

    Behavior on height {
        NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
    }

    // The hard shadow, then the card on it.
    Rectangle {
        x: 3
        y: 3
        width: ec.width - 3
        height: ec.height - 3
        radius: 13
        color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: body
        width: ec.width - 3
        height: ec.height - 3
        radius: 13
        antialiasing: true
        clip: true
        color: Theme.pSurface
        border.width: ec.expanded ? 3 : 2.5
        border.color: ec.expanded ? ec.accent : Theme.pLine
        opacity: ec.done ? 0.72 : 1

        // Click anywhere on the card (the buttons below sit on top of this).
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: ec.toggled()
        }

        // The day block: the weekday over the date, as a sticker, on the entry's colour.
        Slant {
            id: block
            x: 7
            y: 6
            width: 56
            height: 40
            skew: 0.16
            radius: 8
            color: ec.accent
            borderColor: Theme.pLine
            borderWidth: 2
        }

        Column {
            x: block.x
            y: block.y
            width: block.width
            height: block.height
            spacing: -2

            Item { width: 1; height: 4 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ec.weekdayText
                color: Theme.colBorder
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            StickerText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ec.pdate ? String(ec.pdate.d) : ""
                pixelSize: 21
                popOnChange: false
                fillColor: "#ffffff"
                ringColor: ec.accent
            }
        }

        // The title, and under it the time and note.
        Text {
            x: 74
            y: 8
            width: Math.max(0, ec.width - 3 - 74 - chipShape.width - 16)
            text: ec.ev.title
            elide: Text.ElideRight
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            font.strikeout: ec.done
        }

        Row {
            x: 74
            y: 30
            width: ec.width - 3 - 74 - 10
            spacing: 4

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: ec.deadline ? "flag" : "schedule"
                size: 14
                weight: 700
                fill: ec.deadline ? 1 : 0
                color: ec.deadline ? ec.stateInk : Theme.pInkSub
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 18
                elide: Text.ElideRight
                text: EM.timeText(ec.ev.time, ec.use24h) + (ec.ev.note !== "" ? "  \u00b7  " + ec.ev.note : "")
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        // The countdown chip, top right. Text goes NEXT to the Slant (a child would lean with it).
        Slant {
            id: chipShape
            x: ec.width - 3 - width - 8
            y: 8
            width: chipLabel.implicitWidth + 22 + height * skew
            height: 22
            skew: 0.2
            radius: 8
            color: ec.chipFill
            borderColor: Theme.pLine
            borderWidth: 2
        }

        Text {
            id: chipLabel
            x: chipShape.x + (chipShape.width - implicitWidth) / 2
            y: chipShape.y + (chipShape.height - implicitHeight) / 2
            text: ec.chipText
            color: ec.chipInk
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(10.5)
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        // ===== the opened card =====
        Item {
            id: detail
            x: 10
            y: ec.face
            width: body.width - 20
            height: detailCol.implicitHeight
            visible: ec.height > ec.face + 4
            opacity: ec.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            Column {
                id: detailCol
                width: parent.width
                spacing: 6

                Text {
                    width: parent.width
                    text: ec.pdate
                        ? CM.weekdayLong(new Date(ec.pdate.y, ec.pdate.m, ec.pdate.d).getDay()) + ", "
                          + ec.pdate.d + " " + CM.monthShort(ec.pdate.m) + " " + ec.pdate.y
                          + "  \u00b7  " + EM.timeText(ec.ev.time, ec.use24h)
                        : ""
                    elide: Text.ElideRight
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(11.5)
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    visible: ec.ev.note !== ""
                    width: parent.width
                    text: ec.ev.note
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Row {
                    spacing: 6

                    CalendarChip {
                        visible: ec.deadline
                        primary: !ec.done
                        icon: ec.done ? "undo" : "check"
                        label: ec.done ? "Undo" : "Done"
                        onClicked: ec.doneToggled()
                    }

                    CalendarChip {
                        icon: "edit"
                        label: "Edit"
                        onClicked: ec.editRequested()
                    }

                    CalendarChip {
                        danger: true
                        icon: "delete"
                        label: "Delete"
                        onClicked: ec.deleteRequested()
                    }
                }
            }
        }
    }
}
