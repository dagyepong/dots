import QtQuick
import Quickshell
import Quickshell.Io
import "../../common/functions/Extras.js" as X
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The dock's Clipboard key (Dock.qml): the last copies, newest first. Click one to put
// it back on the clipboard (the card then closes); the x deletes it from the history.
// Same history the launcher's "clip" search shows (cliphist + wl-clipboard; the shell
// already keeps `wl-paste --watch cliphist store` running, see ExtrasSource.qml).
DockCard {
    id: root

    signal closeRequested()
    // Open the full history in the launcher.
    signal moreRequested()

    property var entries: []
    property bool missing: false

    readonly property int shownMax: 8
    readonly property real rowH: 40
    readonly property real listW: 360

    contentWidth: root.listW
    contentHeight: header.height + 12 + Math.max(1, Math.min(root.entries.length, root.shownMax)) * (root.rowH + 3)
        + (root.entries.length > root.shownMax ? 34 : 0)

    // Reads the history each time the card opens.
    onOpenChanged: {
        if (root.open)
            root.refresh()
    }

    function refresh() {
        list.running = false
        list.running = true
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.missing = false
                root.entries = X.parseClipList(text)
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.missing = true
                root.entries = []
            }
        }
    }

    function copyEntry(entry) {
        if (entry.image) {
            // A picture goes back with its own type (png, jpeg...), found from the
            // file itself, so what you paste is the same picture (same as the launcher).
            Quickshell.execDetached(["sh", "-c",
                "f=$(mktemp) && cliphist decode \"$1\" > \"$f\" && t=$(file -b --mime-type \"$f\" 2>/dev/null); "
                + "case \"$t\" in image/*) ;; *) t=image/png;; esac; wl-copy --type \"$t\" < \"$f\"; rm -f \"$f\"", "sh", entry.id])
        } else {
            Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", entry.id])
        }
        root.closeRequested()
    }

    function deleteEntry(entry) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", entry.id])
        root.entries = root.entries.filter(e => e.id !== entry.id)
    }

    Row {
        id: header
        x: root.pad
        y: root.pad
        spacing: 9

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 13
            height: 13
            radius: 4
            rotation: 45
            color: Theme.accentMint
            border.width: 2
            border.color: Theme.line
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Clipboard"
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    Text {
        visible: root.entries.length === 0
        x: root.pad
        y: root.pad + header.height + 12
        width: root.listW
        wrapMode: Text.WordWrap
        text: root.missing
            ? "Needs cliphist and wl-clipboard installed."
            : "Nothing copied yet."
        color: Theme.inkSub
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.Bold
    }

    Column {
        x: root.pad
        y: root.pad + header.height + 12
        width: root.listW
        spacing: 3

        Repeater {
            model: root.entries.slice(0, root.shownMax)

            delegate: Item {
                id: row
                required property var modelData

                width: root.listW
                height: root.rowH

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: area.containsMouse
                        ? Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, area.pressed ? 0.34 : 0.2)
                        : "transparent"
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }
                }

                MaterialIcon {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.modelData.image ? "image" : "notes"
                    size: 20
                }

                Text {
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.listW - 40 - 44
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: row.modelData.image ? X.imageLabel(row.modelData.preview) : row.modelData.preview.replace(/\s+/g, " ").trim()
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyEntry(row.modelData)
                }

                // Delete from the history. After the row's own MouseArea so it takes its click.
                Rectangle {
                    x: root.listW - width - 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 8
                    color: Theme.surface
                    border.width: 2
                    border.color: delArea.containsMouse ? "#e0575b" : Theme.line
                    opacity: area.containsMouse || delArea.containsMouse ? 1 : 0
                    visible: opacity > 0.01
                    antialiasing: true

                    Behavior on opacity {
                        NumberAnimation { duration: 110 }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "delete"
                        size: 16
                        weight: 700
                    }

                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteEntry(row.modelData)
                    }
                }
            }
        }

        // More than fits: open the whole history in the launcher.
        Item {
            visible: root.entries.length > root.shownMax
            width: root.listW
            height: 34

            DockButton {
                anchors.centerIn: parent
                height: 30
                icon: "search"
                label: "More in search"
                fontSize: 13
                iconSize: 18
                onClicked: root.moreRequested()
            }
        }
    }
}
