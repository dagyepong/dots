import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

// The Settings panel: a floating card in the middle of the screen, always the same size (never a window that
// opens next to the others). Alt+O shows and hides it; Esc or a click outside closes it.
Scope {
    id: root

    readonly property var sections: [
        { id: "appearance",    label: "Appearance",             icon: "star",      file: "PageAppearance.qml" },
        { id: "bar",           label: "Bar & clock",            icon: "grid",      file: "PageBar.qml" },
        { id: "notifications", label: "Notifications & OSD",    icon: "bell",      file: "PageNotifications.qml" },
        { id: "wallpaper",     label: "Wallpaper, lock & idle", icon: "lock",      file: "PageWallpaper.qml" },
        { id: "displays",      label: "Monitors & display",     icon: "focus",     file: "PageDisplays.qml" },
        { id: "network",       label: "Network",                icon: "wifi",      file: "PageNetwork.qml" },
        { id: "bluetooth",     label: "Bluetooth",              icon: "bluetooth", file: "PageBluetooth.qml" },
        { id: "audio",         label: "Audio",                  icon: "volume",    file: "PageAudio.qml" },
        { id: "power",         label: "Power & battery",        icon: "power",     file: "PagePower.qml" },
        { id: "keys",          label: "Shortcuts",              icon: "gear",      file: "PageKeys.qml" },
        { id: "about",         label: "About",                  icon: "flag",      file: "PageAbout.qml" }
    ]

    function fileFor(id) {
        for (let i = 0; i < sections.length; i++) if (sections[i].id === id) return sections[i].file
        return sections[0].file
    }


    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            readonly property bool here: Settings.open
                && (Settings.screenName === "" || Settings.screenName === modelData.name)

            visible: here || card.opacity > 0
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell-settings"
            WlrLayershell.keyboardFocus: win.here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onHereChanged: if (here) keys.forceActiveFocus()

            // Click outside the card closes it
            MouseArea {
                anchors.fill: parent
                onClicked: Settings.open = false
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Settings.open = false
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(1120, win.width - 60)
                height: Math.min(700, win.height - 60)
                radius: 26
                color: Theme.island
                border.width: 1
                border.color: Theme.border
                clip: true
                opacity: win.here ? 1 : 0
                scale: win.here ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                // Clicks inside the card do not reach the closing area
                MouseArea { anchors.fill: parent }

                Rectangle {
                    id: side
                    width: 240
                    height: parent.height
                    color: Theme.surfaceSoft

                    Text {
                        x: 22; y: 22
                        text: "Settings"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Column {
                        x: 12
                        y: 70
                        width: side.width - 24
                        spacing: 2

                        Repeater {
                            model: root.sections

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool on: Settings.page === modelData.id

                                width: parent.width
                                height: 38
                                radius: 12
                                color: on ? Theme.island : (mouse.containsMouse ? Theme.islandHover : "transparent")
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Rectangle {
                                    visible: parent.on
                                    x: 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 18
                                    radius: 2
                                    color: Theme.accent
                                }

                                Glyph {
                                    x: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    kind: modelData.icon
                                    level: 2
                                    size: 15
                                    color: parent.on ? Theme.accent : Theme.muted
                                }

                                Text {
                                    x: 44
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: parent.on ? Theme.foreground : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: parent.on
                                }

                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Settings.page = modelData.id
                                }
                            }
                        }
                    }
                }

                Loader {
                    x: side.width
                    width: parent.width - side.width
                    height: parent.height
                    active: win.here || card.opacity > 0
                    source: root.fileFor(Settings.page)
                }
            }
        }
    }
}
