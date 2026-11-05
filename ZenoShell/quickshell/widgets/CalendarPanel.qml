import QtQuick
import qs.theme
import qs.services

// Panel: month calendar; a click on a day opens its notes in the same space
Item {
    id: root

    width: 340
    height: 330

    property bool dragging: dayMode
    property bool dayMode: false
    property int dayYear: 2000
    property int dayMonth: 0
    property int dayDay: 1

    property var today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    function shiftMonth(d) {
        let m = viewMonth + d
        let y = viewYear
        if (m < 0) { m = 11; y-- }
        else if (m > 11) { m = 0; y++ }
        viewMonth = m
        viewYear = y
    }

    onVisibleChanged: {
        if (visible) {
            today = new Date()
            viewYear = today.getFullYear()
            viewMonth = today.getMonth()
        } else {
            dayMode = false
        }
    }

    Rectangle {
        x: 10; y: 10
        width: parent.width - 20
        height: parent.height - 20
        radius: 22
        color: Theme.surfaceSoft
    }

    DayNotes {
        x: 24; y: 24
        width: 292; height: 282
        visible: root.dayMode
        year: root.dayYear
        month: root.dayMonth
        day: root.dayDay
        onCloseRequested: root.dayMode = false
        onVisibleChanged: if (visible) reset()
    }

    Row {
        x: 24; y: 24
        width: 292
        height: 28
        visible: !root.dayMode

        NavButton {
            width: 28; height: 28
            label: "‹"
            onClicked: root.shiftMonth(-1)
        }

        Text {
            width: parent.width - 56
            height: 28
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Qt.locale("en_US").monthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
        }

        NavButton {
            width: 28; height: 28
            label: "›"
            onClicked: root.shiftMonth(1)
        }
    }

    MonthGrid {
        x: 24; y: 62
        visible: !root.dayMode
        cellW: 41
        cellH: 31
        year: root.viewYear
        month: root.viewMonth
        today: root.today
        onDayClicked: d => {
            root.dayYear = d.getFullYear()
            root.dayMonth = d.getMonth()
            root.dayDay = d.getDate()
            root.dayMode = true
        }
    }
}
