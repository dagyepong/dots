import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    property int year: 2000
    property int month: 0
    property int day: 1

    signal closeRequested()

    property string editingId: ""

    readonly property string dateKey: Notes.keyOfYMD(year, month, day)
    readonly property var items: Notes.forDate(dateKey)

    readonly property string heading: {
        const d = new Date(year, month, day)
        const wd = Qt.locale("en_US").dayName(d.getDay(), Locale.LongFormat)
        const mn = Qt.locale("en_US").monthName(month, Locale.LongFormat)
        return wd.charAt(0).toUpperCase() + wd.slice(1) + " " + day + " " + mn + " " + year
    }

    // Time: empty = all day, null = badly formatted
    readonly property var timeParsed: parseTime(timeField.text)
    readonly property bool canSave: titleField.text.trim() !== "" && timeParsed !== null

    readonly property int listH: items.length === 0 ? 30 : Math.min(132, listCol.implicitHeight)
    readonly property int formY: 52 + listH + 10

    implicitHeight: formY + 164

    function parseTime(s) {
        const t = s.trim()
        if (t === "") return ""
        const m = /^(\d{1,2})[:.](\d{2})$/.exec(t)
        if (!m) return null
        const h = parseInt(m[1])
        const mi = parseInt(m[2])
        if (h > 23 || mi > 59) return null
        return Notes.pad(h) + ":" + Notes.pad(mi)
    }

    function clearForm() {
        editingId = ""
        titleField.text = ""
        timeField.text = ""
        descField.text = ""
    }

    function reset() {
        clearForm()
        titleField.forceActiveFocus()
    }

    function edit(ev) {
        editingId = ev.id
        titleField.text = ev.title
        timeField.text = ev.time
        descField.text = ev.desc
        titleField.forceActiveFocus()
    }

    function save() {
        if (!canSave) return
        const fields = {
            time: timeParsed,
            title: titleField.text.trim(),
            desc: descField.text.trim()
        }
        if (editingId !== "") Notes.update(editingId, fields)
        else Notes.add(dateKey, fields.time, fields.title, fields.desc)
        clearForm()
        titleField.forceActiveFocus()
    }

    // ---------- Header ----------
    NavButton {
        x: 14; y: 14
        label: "‹"
        onClicked: root.closeRequested()
    }

    Text {
        x: 52; y: 14
        height: 28
        verticalAlignment: Text.AlignVCenter
        text: root.heading
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 14
        height: 28
        verticalAlignment: Text.AlignVCenter
        text: root.items.length === 0 ? "" : root.items.length + (root.items.length === 1 ? " note" : " notes")
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    // ---------- Notes of the day ----------
    Text {
        x: 18; y: 52
        height: 30
        verticalAlignment: Text.AlignVCenter
        visible: root.items.length === 0
        text: "No notes yet: write below and press Save"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    Flickable {
        x: 14; y: 52
        width: root.width - 28
        height: root.listH
        contentHeight: listCol.implicitHeight
        clip: true
        visible: root.items.length > 0
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: listCol
            width: parent.width
            spacing: 6

            Repeater {
                model: root.items

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    width: listCol.width
                    height: 44
                    radius: 14
                    color: root.editingId === modelData.id ? Theme.islandHover : Theme.surfaceSoft
                    border.width: root.editingId === modelData.id ? 1 : 0
                    border.color: Theme.note

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.edit(row.modelData)
                    }

                    Rectangle {
                        x: 8; y: 11
                        width: 48; height: 22
                        radius: 11
                        color: Qt.rgba(Theme.note.r, Theme.note.g, Theme.note.b, 0.22)

                        Text {
                            anchors.centerIn: parent
                            text: row.modelData.time !== "" ? row.modelData.time : "all day"
                            color: Theme.note
                            font.family: Theme.fontFamily
                            font.pixelSize: row.modelData.time !== "" ? 11 : 8
                            font.bold: true
                        }
                    }

                    Column {
                        x: 64
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 64 - 34
                        spacing: 1

                        Text {
                            width: parent.width
                            text: row.modelData.title
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: row.modelData.desc !== ""
                            text: row.modelData.desc.replace(/\n/g, " ")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"
                        color: Theme.muted
                        font.pixelSize: 17

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.editingId === row.modelData.id) root.clearForm()
                                Notes.remove(row.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- Modulo: titolo + orario ----------
    Rectangle {
        id: titleBox
        x: 14
        y: root.formY
        width: root.width - 28 - 86
        height: 34
        radius: 17
        color: Theme.surfaceSoft
        border.width: titleField.activeFocus ? 1 : 0
        border.color: Theme.accent

        TextInput {
            id: titleField
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            clip: true
            selectByMouse: true
            KeyNavigation.tab: timeField
            onAccepted: root.save()
            Keys.onEscapePressed: root.closeRequested()
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: titleField.text === ""
            text: "Title"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    Rectangle {
        x: titleBox.x + titleBox.width + 8
        y: root.formY
        width: 78
        height: 34
        radius: 17
        color: Theme.surfaceSoft
        border.width: (timeField.text !== "" && root.timeParsed === null) || timeField.activeFocus ? 1 : 0
        border.color: (timeField.text !== "" && root.timeParsed === null) ? Theme.danger : Theme.accent

        TextInput {
            id: timeField
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            clip: true
            KeyNavigation.tab: descField
            onAccepted: root.save()
            Keys.onEscapePressed: root.closeRequested()
        }

        Text {
            anchors.centerIn: parent
            visible: timeField.text === ""
            text: "HH:MM"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    // ---------- Modulo: descrizione ----------
    Rectangle {
        x: 14
        y: root.formY + 42
        width: root.width - 28
        height: 58
        radius: 16
        color: Theme.surfaceSoft
        border.width: descField.activeFocus ? 1 : 0
        border.color: Theme.accent

        TextEdit {
            id: descField
            anchors.fill: parent
            anchors.margins: 12
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: TextEdit.Wrap
            clip: true
            selectByMouse: true

            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        && (event.modifiers & Qt.ControlModifier)) {
                    root.save()
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab) {
                    titleField.forceActiveFocus()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    root.closeRequested()
                    event.accepted = true
                }
            }
        }

        Text {
            x: 12; y: 12
            visible: descField.text === ""
            text: "Description (optional)"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    // ---------- Pulsanti ----------
    Rectangle {
        x: 14
        y: root.formY + 42 + 58 + 8
        width: 110
        height: 32
        radius: 16
        color: clearMouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft

        Text {
            anchors.centerIn: parent
            text: root.editingId !== "" ? "Cancel edit" : "Clear"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.clearForm()
                titleField.forceActiveFocus()
            }
        }
    }

    Rectangle {
        x: root.width - 14 - width
        y: root.formY + 42 + 58 + 8
        width: 110
        height: 32
        radius: 16
        color: Theme.accent
        opacity: root.canSave ? 1 : 0.4
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: root.editingId !== "" ? "Update" : "Save"
            color: Theme.island
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.save()
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.formY + 42 + 58 + 8 + 32 + 10
        text: "Reminders: the evening before at " + Notes.dayBeforeHour + ":00 and at the note's time"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 9
    }
}
