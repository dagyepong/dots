import QtQuick
import qs.theme
import qs.services
import qs.settings

// Step 7: the shortcuts, by groups, with a "Try" button that really does the action
WStep {
    id: root
    title: "Your shortcuts"
    subtitle: "Mod is the Super key. The same keys work on niri and Hyprland. Press Try to see what each one does."

    property int group: 0

    // try: command for "qs ipc call"; menu: true if it opens a menu (the tour steps aside until it closes)
    readonly property var groups: [
        { name: "Menus", icon: "grid", rows: [
            { keys: "Mod+R  or  Alt+R", what: "Launcher: type to search apps, Enter opens", cmd: ["launcher", "toggle"], menu: true },
            { keys: "Mod+M  or  Alt+P", what: "Power menu: lock, log out, suspend, reboot, power off", cmd: ["power", "toggle"], menu: true },
            { keys: "Alt+W", what: "Wallpaper picker", cmd: ["wallpaper", "toggle"], menu: true },
            { keys: "Alt+I", what: "System resources: CPU, RAM, disk", cmd: ["system", "toggle"], menu: false },
            { keys: "Alt+O", what: "Settings" },
            { keys: "Alt+L", what: "Lock the screen" }
        ] },
        { name: "Look", icon: "star", rows: [
            { keys: "Alt+S", what: "Style picker", cmd: ["style", "toggle"], menu: true },
            { keys: "Mod+Alt+1 … 4", what: "Island, Classic, Dashboard, Vertical, straight away" },
            { keys: "Alt+T", what: "Theme picker: arrows to browse, Enter to apply", cmd: ["theme", "toggle"], menu: true },
            { keys: "Mod+Alt+T", what: "Light / dark", cmd: ["theme", "mode", "toggle"], menu: false },
            { keys: "Alt+V", what: "Dashboard version: pill or attached", cmd: ["style", "variant"], menu: true }
        ] },
        { name: "Modes", icon: "game", rows: [
            { keys: "Alt+G", what: "Game Mode: no animations, blur, gaps. Press again to undo", cmd: ["gamemode", "toggle"], menu: false },
            { keys: "Alt+E", what: "Eco Mode: less power, dimmer screen. Press again to undo", cmd: ["powersaver", "toggle"], menu: false },
            { keys: "Alt+D", what: "Do Not Disturb", cmd: ["dnd", "toggle"], menu: false },
            { keys: "Alt+Tab", what: "Show the workspaces", cmd: ["workspaces", "peek"], menu: false },
            { keys: "Mod+Space", what: "Next keyboard layout", cmd: ["layout", "next"], menu: false }
        ] },
        { name: "Capture", icon: "play", rows: [
            { keys: "Print", what: "Screenshot and recording menu", cmd: ["capture", "toggle"], menu: true },
            { keys: "Mod+H  /  Mod+Shift+H  /  Mod+Ctrl+H", what: "Screenshot: screen, area, window" },
            { keys: "Mod+Alt+H  /  Mod+Alt+Shift+H", what: "Record the screen / an area (press again to stop)" },
            { keys: "Mod+Alt+P", what: "Pause the recording" }
        ] },
        { name: "Windows", icon: "focus", rows: [
            { keys: "Mod+Return  F  E", what: "Terminal, browser, files" },
            { keys: "Mod+Q", what: "Close the window" },
            { keys: "Mod+1 … 0", what: "Go to a workspace (with Shift: send the window there)" },
            { keys: "Mod+arrows", what: "Move the focus (with Shift: move the window)" },
            { keys: "Mod+Ctrl+F  /  Mod+Shift+F", what: "Full screen / maximize" }
        ] }
    ]

    // ---- groups on the left ----
    Column {
        id: tabs
        width: 190
        spacing: 6

        Repeater {
            model: root.groups

            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: root.group === index

                width: tabs.width
                height: 46
                radius: 14
                color: on ? Theme.accent : (tabMouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft)
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: parent.on ? Theme.island : Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: parent.on
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.group = index
                }
            }
        }
    }

    // ---- rows on the right ----
    Rectangle {
        x: tabs.width + 20
        width: parent.width - x
        height: parent.height
        radius: 22
        color: Theme.surfaceSoft
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 8
            contentHeight: rowsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: rowsCol
                width: parent.width

                Repeater {
                    model: root.groups[root.group].rows

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: rowsCol.width
                        height: 56

                        Rectangle {
                            id: chip
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(260, keyText.implicitWidth + 22)
                            height: 28
                            radius: 9
                            color: Theme.island
                            border.width: 1
                            border.color: Theme.border

                            Text {
                                id: keyText
                                anchors.centerIn: parent
                                width: parent.width - 12
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: modelData.keys
                                color: Theme.foreground
                                font.family: "monospace"
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            x: 290
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 290 - (modelData.cmd ? 100 : 12)
                            text: modelData.what
                            wrapMode: Text.WordWrap
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        SButton {
                            visible: modelData.cmd !== undefined
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Try"
                            onClicked: Welcome.run(modelData.cmd, modelData.menu)
                        }

                        Rectangle {
                            visible: index < root.groups[root.group].rows.length - 1
                            anchors.bottom: parent.bottom
                            x: 10
                            width: parent.width - 20
                            height: 1
                            color: Theme.border
                            opacity: 0.45
                        }
                    }
                }
            }
        }
    }
}
