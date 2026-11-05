import QtQuick
import qs.theme
import qs.services

SPage {
    id: root
    title: "Appearance"
    subtitle: "How the shell looks. Colors always follow the wallpaper, through pywal."

    SSection {
        title: "Style"

        SRow {
            title: "Shell style"
            hint: "Island, Classic, Dashboard or Vertical. Also with Alt+S."
            SChoice {
                model: Style.styles.map(s => ({ id: s.id, label: s.name }))
                current: Style.current
                onPicked: id => Style.set(id)
            }
        }

        SRow {
            last: true
            title: "Dashboard version"
            hint: "Only for the Dashboard style: a floating pill, or a bar fused with the top edge. Also with Alt+V."
            SChoice {
                model: Style.dashVariants.map(v => ({ id: v.id, label: v.name }))
                current: Style.dashVariant
                onPicked: id => Style.setDashVariant(id)
            }
        }
    }

    SSection {
        title: "Colors"

        SRow {
            title: "Light or dark"
            hint: "Regenerates the palette from the wallpaper, so the shell, kitty and Firefox change together. Also with Mod+Alt+T."
            SChoice {
                model: [{ id: "dark", label: "Dark" }, { id: "light", label: "Light" }]
                current: Appearance.mode
                onPicked: id => Appearance.setMode(id)
            }
        }

        Item {
            width: parent.width
            height: themeFlow.implicitHeight + 28

            Text {
                x: 12; y: 8
                text: "Theme"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Flow {
                id: themeFlow
                x: 12
                y: 34
                width: parent.width - 24
                spacing: 10

                Repeater {
                    model: Appearance.themes

                    delegate: Rectangle {
                        required property var modelData
                        readonly property var pv: Theme.preview(modelData.id)
                        readonly property bool current: Appearance.theme === modelData.id

                        width: 132
                        height: 74
                        radius: 14
                        color: pv.island
                        border.width: current ? 2 : 1
                        border.color: current ? Theme.accent : Theme.border

                        Row {
                            x: 12; y: 12
                            spacing: 5
                            Rectangle { width: 16; height: 16; radius: 8; color: pv.accent }
                            Rectangle { width: 16; height: 16; radius: 8; color: pv.note }
                            Rectangle { width: 16; height: 16; radius: 8; color: pv.muted }
                        }

                        Text {
                            x: 12
                            y: parent.height - height - 10
                            text: modelData.name
                            color: pv.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: parent.current
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
    }
}
