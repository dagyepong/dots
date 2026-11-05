import QtQuick
import qs.theme
import qs.services

// Compact notes editor for one day (lives inside the dashboard's calendar space, 196 x 212)
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
        return Qt.locale("en_US").toString(d, "ddd, MMM d")
    }

    // Time: empty = all day, null = badly formatted
    readonly property var timeParsed: parseTime(timeField.text)
    readonly property bool canSave: titleField.text.trim() !== "" && timeParsed !== null

    readonly property int listH: items.length === 0 ? 22 : Math.min(64, listCol.implicitHeight)
    readonly property int formY: 30 + listH + 6

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
        x: 0; y: 0
        width: 24; height: 24
        label: "‹"
        onClicked: root.closeRequested()
    }

    Text {
        x: 30; y: 0
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: root.heading
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.bold: true
    }

    Text {
        anchors.right: parent.right
        y: 0
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: root.items.length === 0 ? "" : root.items.length + (root.items.length === 1 ? " note" : " notes")
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 9
    }

    // ---------- Notes of the day ----------
    Text {
        x: 4; y: 30
        height: 22
        verticalAlignment: Text.AlignVCenter
        visible: root.items.length === 0
        text: "No notes yet"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    Flickable {
        x: 0; y: 30
        width: root.width
        height: root.listH
        contentHeight: listCol.implicitHeight
        clip: true
        visible: root.items.length > 0
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: listCol
            width: parent.width
            spacing: 4

            Repeater {
                model: root.items

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    width: listCol.width
                    height: 30
                    radius: 10
                    color: root.editingId === modelData.id ? Theme.islandHover : Theme.island
                    border.width: root.editingId === modelData.id ? 1 : 0
                    border.color: Theme.note

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.edit(row.modelData)
                    }

                    Rectangle {
                        x: 5; y: 6
                        width: 38; height: 18
                        radius: 9
                        color: Qt.rgba(Theme.note.r, Theme.note.g, Theme.note.b, 0.22)

                        Text {
                            anchors.centerIn: parent
                            text: row.modelData.time !== "" ? row.modelData.time : "all day"
                            color: Theme.note
                            font.family: Theme.fontFamily
                            font.pixelSize: row.modelData.time !== "" ? 10 : 7
                            font.bold: true
                        }
                    }

                    Text {
                        x: 50
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 50 - 24
                        text: row.modelData.title
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"
                        color: Theme.muted
                        font.pixelSize: 15

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
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

    // ---------- Form: title + time ----------
    Rectangle {
        id: titleBox
        x: 0
        y: root.formY
        width: root.width - 62
        height: 28
        radius: 14
        color: Theme.island
        border.width: titleField.activeFocus ? 1 : 0
        border.color: Theme.accent

        TextInput {
            id: titleField
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
            clip: true
            selectByMouse: true
            KeyNavigation.tab: timeField
            onAccepted: root.save()
            Keys.onEscapePressed: root.closeRequested()
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: titleField.text === ""
            text: "Title"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    Rectangle {
        x: titleBox.width + 6
        y: root.formY
        width: 56
        height: 28
        radius: 14
        color: Theme.island
        border.width: (timeField.text !== "" && root.timeParsed === null) || timeField.activeFocus ? 1 : 0
        border.color: (timeField.text !== "" && root.timeParsed === null) ? Theme.danger : Theme.accent

        TextInput {
            id: timeField
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
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
            font.pixelSize: 10
        }
    }

    // ---------- Form: description ----------
    Rectangle {
        x: 0
        y: root.formY + 34
        width: root.width
        height: 38
        radius: 12
        color: Theme.island
        border.width: descField.activeFocus ? 1 : 0
        border.color: Theme.accent

        TextEdit {
            id: descField
            anchors.fill: parent
            anchors.margins: 8
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
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
            x: 8; y: 8
            visible: descField.text === ""
            text: "Description (optional)"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }

    // ---------- Buttons ----------
    Rectangle {
        x: 0
        y: root.formY + 34 + 38 + 6
        width: (root.width - 6) / 2
        height: 26
        radius: 13
        color: clearMouse.containsMouse ? Theme.islandHover : Theme.island

        Text {
            anchors.centerIn: parent
            text: root.editingId !== "" ? "Cancel" : "Clear"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 10
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
        x: (root.width - 6) / 2 + 6
        y: root.formY + 34 + 38 + 6
        width: (root.width - 6) / 2
        height: 26
        radius: 13
        color: Theme.accent
        opacity: root.canSave ? 1 : 0.4
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: root.editingId !== "" ? "Update" : "Save"
            color: Theme.island
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.save()
        }
    }
}
