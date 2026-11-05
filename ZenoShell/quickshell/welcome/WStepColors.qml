import QtQuick
import qs.theme
import qs.services
import qs.settings

// Step 3: light or dark, the theme and the wallpaper
WStep {
    title: "Colors"
    subtitle: "All the colors come from your wallpaper. Choose light or dark and how the shell uses them."

    Row {
        y: 4
        spacing: 24

        Column {
            spacing: 10
            Text { text: "Mode"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true }
            SChoice {
                base: Theme.surfaceSoft
                model: [{ id: "dark", label: "Dark" }, { id: "light", label: "Light" }]
                current: Appearance.mode
                onPicked: id => Appearance.setMode(id)
            }
        }

        Column {
            spacing: 10
            Text { text: "Wallpaper"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true }
            SButton {
                base: Theme.surfaceSoft
                label: "Choose a wallpaper…"
                accent: true
                onClicked: Welcome.run(["wallpaper", "toggle"], true)
            }
        }
    }

    Text {
        y: 86
        text: "Theme"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.bold: true
    }

    Flow {
        y: 116
        width: parent.width
        spacing: 12

        Repeater {
            model: Appearance.themes

            delegate: Rectangle {
                required property var modelData
                readonly property var pv: Theme.preview(modelData.id)
                readonly property bool current: Appearance.theme === modelData.id

                width: 176
                height: 96
                radius: 18
                color: pv.island
                border.width: current ? 2 : 1
                border.color: current ? Theme.accent : Theme.border
                scale: current ? 1.0 : 0.97
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                Row {
                    x: 14; y: 14; spacing: 6
                    Rectangle { width: 22; height: 22; radius: 11; color: pv.accent }
                    Rectangle { width: 22; height: 22; radius: 11; color: pv.note }
                    Rectangle { width: 22; height: 22; radius: 11; color: pv.muted }
                }

                Text {
                    x: 14
                    y: 52
                    text: modelData.name
                    color: pv.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    x: 14
                    y: 72
                    width: parent.width - 24
                    text: modelData.hint
                    elide: Text.ElideRight
                    color: pv.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Appearance.setTheme(modelData.id)
                }
            }
        }
    }
}
