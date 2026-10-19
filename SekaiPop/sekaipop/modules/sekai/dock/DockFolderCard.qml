import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// A folder's apps (Dock.qml): the card that opens over a folder key. Each app is
// a small tile: click opens it (or jumps to it when it is running), the x that
// shows under the pointer takes it out of the folder.
//
// `apps` is a list of { class, iconName, displayName, running } made by Dock.qml.
DockCard {
    id: root

    property string title: ""
    property var apps: []

    signal openApp(string cls)
    signal removeApp(string cls)

    readonly property real tileW: 84
    readonly property real tileH: 92
    readonly property int cols: Math.max(1, Math.min(4, root.apps.length))
    readonly property int rowsN: Math.max(1, Math.ceil(root.apps.length / root.cols))

    contentWidth: Math.max(root.cols * root.tileW + (root.cols - 1) * 10, 250)
    contentHeight: header.height + 12 + root.rowsN * root.tileH + (root.rowsN - 1) * 10

    // The title, and a pencil to rename the folder: the name turns into a text box (Enter
    // keeps it, Esc leaves it as it was).
    property bool editing: false
    signal renamed(string name)

    function beginEdit() {
        root.editing = true
        nameInput.text = root.title
        nameInput.forceActiveFocus()
        nameInput.selectAll()
    }

    function commitEdit() {
        const n = nameInput.text.trim()
        root.editing = false
        if (n !== "" && n !== root.title)
            root.renamed(n)
    }

    onOpenChanged: {
        if (!root.open)
            root.editing = false
    }

    Item {
        id: header
        x: root.pad
        y: root.pad
        width: root.contentWidth
        height: 34

        Row {
            anchors.verticalCenter: parent.verticalCenter
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
                visible: !root.editing
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Rectangle {
                visible: root.editing
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: 30
                radius: 9
                color: Theme.surface
                border.width: 2.5
                border.color: Theme.accentCyan
                antialiasing: true

                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    maximumLength: 24
                    color: Theme.ink
                    selectionColor: Theme.accentCyan
                    selectedTextColor: Theme.colBorder
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.ExtraBold
                    onAccepted: root.commitEdit()
                    Keys.onEscapePressed: root.editing = false
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            DockButton {
                visible: !root.editing
                height: 30
                icon: "edit"
                iconSize: 18
                onClicked: root.beginEdit()
            }

            DockButton {
                visible: root.editing
                height: 30
                icon: "check"
                iconSize: 18
                accent: true
                onClicked: root.commitEdit()
            }
        }
    }

    Grid {
        x: root.pad
        y: root.pad + header.height + 12
        columns: root.cols
        spacing: 10

        Repeater {
            model: root.apps

            delegate: Item {
                id: tile
                required property var modelData

                width: root.tileW
                height: root.tileH

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: area.containsMouse
                        ? Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, area.pressed ? 0.34 : 0.2)
                        : "transparent"
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }
                }

                Image {
                    id: icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    width: 46
                    height: 46
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(92, 92)
                    source: IconCursorService.path(tile.modelData.iconName, "application-x-executable")
                    scale: area.containsMouse ? 1.08 : 1
                    Behavior on scale {
                        NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 58
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tile.modelData.displayName
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }

                // Running: the same small diamond the dock's keys use.
                DockRunDot {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 14
                    mode: tile.modelData.running ? "running" : "none"
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openApp(tile.modelData.class)
                }

                // Take it out of the folder. After the tile's own MouseArea, so it
                // takes its own click.
                Rectangle {
                    x: tile.width - width - 2
                    y: 2
                    width: 22
                    height: 22
                    radius: 7
                    color: Theme.surface
                    border.width: 2
                    border.color: outArea.containsMouse ? Theme.accentMint : Theme.line
                    opacity: area.containsMouse || outArea.containsMouse ? 1 : 0
                    visible: opacity > 0.01
                    antialiasing: true

                    Behavior on opacity {
                        NumberAnimation { duration: 110 }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 14
                        weight: 700
                    }

                    MouseArea {
                        id: outArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeApp(tile.modelData.class)
                    }
                }
            }
        }
    }
}
