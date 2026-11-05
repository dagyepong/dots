import QtQuick
import qs.theme
import qs.services

SPage {
    id: root
    title: "Shortcuts"
    subtitle: "The keys of the shell, the same on niri and Hyprland. Mod is the Super key. To change one, edit niri/quickshell.kdl or hypr/quickshell-binds.lua; the commands are in the README."

    readonly property var groups: [
        { name: "Launch", keys: [
            ["Mod+R  /  Alt+R", "Launcher"], ["Mod+M  /  Alt+P", "Power menu"], ["Alt+L", "Lock the screen"],
            ["Alt+O", "These settings"], ["Alt+W", "Wallpaper picker"], ["Alt+I", "System resources"] ] },
        { name: "Look", keys: [
            ["Alt+S", "Style picker"], ["Mod+Alt+1 … 4", "Island, Classic, Dashboard, Vertical"], ["Alt+T", "Theme picker"],
            ["Mod+Alt+T", "Light / dark"], ["Alt+V", "Dashboard version"] ] },
        { name: "Modes", keys: [
            ["Alt+G", "Game Mode"], ["Alt+E", "Eco Mode"], ["Alt+D", "Do Not Disturb"],
            ["Mod+Space", "Next keyboard layout"], ["Alt+Tab", "Show the workspaces"] ] },
        { name: "Capture", keys: [
            ["Print", "Screenshot and recording menu"], ["Mod+H  /  Mod+Shift+H  /  Mod+Ctrl+H", "Screenshot: screen / area / window"],
            ["Mod+Alt+H  /  Mod+Alt+Shift+H", "Record the screen / an area"], ["Mod+Alt+P", "Pause the recording"] ] }
    ]

    Repeater {
        model: root.groups

        delegate: SSection {
            required property var modelData
            title: modelData.name

            Repeater {
                model: modelData.keys

                delegate: SRow {
                    required property var modelData
                    required property int index
                    title: modelData[1]
                    last: index === parent.children.length - 2
                    Rectangle {
                        width: keyText.implicitWidth + 20
                        height: 26
                        radius: 8
                        color: Theme.island
                        border.width: 1
                        border.color: Theme.border
                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: modelData[0]
                            color: Theme.foreground
                            font.family: "monospace"
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
