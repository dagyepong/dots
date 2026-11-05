import QtQuick
import qs.theme
import qs.services

// Step 8: how the shell works, in short
WStep {
    id: root
    title: "How it works"
    subtitle: "No magic: a shell made of small QML files, read by Quickshell. Here is the map, in case you want to look inside or change something."

    // ---- the flow of one key press ----
    Row {
        id: flow
        y: 0
        spacing: 0

        Repeater {
            model: [
                { t: "Your key",      d: "niri / Hyprland\nbinds a key" },
                { t: "qs ipc call",   d: "a command that talks\nto the running shell" },
                { t: "ipc/ShellIpc",  d: "receives it and\ncalls a service" },
                { t: "services/",     d: "hold the state:\nAudio, Network, Style…" },
                { t: "widgets/ bar/", d: "draw it on screen,\nthey follow the state" }
            ]

            delegate: Row {
                required property var modelData
                required property int index

                Rectangle {
                    width: (root.area.width - 4 * 26) / 5
                    height: 92
                    radius: 18
                    color: Theme.surfaceSoft
                    border.width: 1
                    border.color: index === 0 ? Theme.accent : Theme.border

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 5
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.t; color: Theme.accent; font.family: "monospace"; font.pixelSize: 12; font.bold: true }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.d; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 10 }
                    }
                }

                Item {
                    visible: index < 4
                    width: 26
                    height: 92
                    Text { anchors.centerIn: parent; text: "›"; color: Theme.muted; font.pixelSize: 22 }
                }
            }
        }
    }

    // ---- where things live ----
    Rectangle {
        y: 112
        width: (parent.width - 16) * 0.56
        height: parent.height - 112
        radius: 22
        color: Theme.surfaceSoft

        Text {
            x: 20; y: 16
            text: "WHERE THINGS LIVE   ~/.config/quickshell/"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1
        }

        Column {
            x: 20; y: 42
            width: parent.width - 40
            spacing: 5

            Repeater {
                model: [
                    ["shell.qml",   "starts everything: bar, OSD, launcher, lock, settings…"],
                    ["bar/",        "the four styles of the bar"],
                    ["widgets/",    "pills, panels, menus, the pieces you see"],
                    ["pages/",      "the pages inside the quick settings and the Dashboard"],
                    ["services/",   "state and the connection with the system (singletons)"],
                    ["theme/",      "colors computed from your wallpaper (pywal)"],
                    ["ipc/",        "the commands `qs ipc call …` that keys use"],
                    ["osd/ lock/ …", "overlays: OSD, lock screen, launcher, settings, this tour"]
                ]

                delegate: Row {
                    required property var modelData
                    spacing: 10
                    Text { width: 112; text: modelData[0]; color: Theme.accent; font.family: "monospace"; font.pixelSize: 11; elide: Text.ElideRight }
                    Text { width: 300; text: modelData[1]; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
                }
            }
        }
    }

    // ---- make it yours ----
    Rectangle {
        x: (parent.width - 16) * 0.56 + 16
        y: 112
        width: parent.width - x
        height: parent.height - 112
        radius: 22
        color: Theme.surfaceSoft

        Text {
            x: 20; y: 16
            text: "MAKE IT YOURS"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1
        }

        Column {
            x: 20; y: 42
            width: parent.width - 40
            spacing: 9

            Repeater {
                model: [
                    "Edit a file in ~/.config/quickshell and save: Quickshell reloads the shell on its own.",
                    "Your choices are saved in ~/.local/state/quickshell/ (settings, style, theme).",
                    "Keys are plain lines in niri/quickshell.kdl or hypr/quickshell-binds.lua: change them, they call `qs ipc call`.",
                    "Everything has a command: `qs ipc show` lists them all.",
                    "The colors follow the wallpaper: pywal writes them, Theme.qml reads them."
                ]

                delegate: Row {
                    required property string modelData
                    spacing: 8
                    Rectangle { y: 5; width: 5; height: 5; radius: 2.5; color: Theme.accent }
                    Text { width: 300; text: modelData; wrapMode: Text.WordWrap; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 11 }
                }
            }
        }
    }
}
