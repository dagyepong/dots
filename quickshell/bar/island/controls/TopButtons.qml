// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T O P   B U T T O N S                                                  │
// │   one side of the control centre's top row · session and panels          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../../theme"
import "../../../services"

// Small buttons, from `ControlsService.topCatalogue`: a session action runs
// (one that ends the session arms on the first click, red and labelled, and
// runs on the second), a door opens its panel or the settings.
RowLayout {
    id: root

    property var entries: []
    property string armed: ""

    // The panel closes on any session action; lock would photograph it.
    signal ran()
    signal panelRequested(string panel)
    signal settingsRequested()

    spacing: 4

    readonly property Timer disarm: Timer {
        interval: 3000
        onTriggered: root.armed = ""
    }

    Repeater {
        model: root.entries

        Rectangle {
            id: button

            required property var modelData
            readonly property bool isArmed: root.armed !== "" && root.armed === button.modelData.id

            Layout.preferredWidth: button.isArmed ? label.implicitWidth + 34 : 32
            Layout.preferredHeight: 28
            radius: Theme.radiusSmall

            color: {
                if (button.isArmed)
                    return Theme.red
                return mouse.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"
            }
            border.color: button.isArmed ? Theme.red
                : (mouse.containsMouse ? Theme.borderIn(QsWindow.window) : "transparent")
            border.width: 1

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: button.modelData.icon
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    color: {
                        if (button.isArmed)
                            return Theme.accentText
                        return mouse.containsMouse ? Theme.accent : Theme.text
                    }
                }

                Text {
                    id: label
                    visible: button.isArmed
                    text: Tr.t(button.modelData.label)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.accentText
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const entry = button.modelData
                    if (!entry.session) {
                        if (entry.panel === "")
                            root.settingsRequested()
                        else
                            root.panelRequested(entry.panel)
                        return
                    }
                    if (!entry.destructive || button.isArmed) {
                        root.armed = ""
                        root.disarm.stop()
                        SessionService.run(entry.id)
                        root.ran()
                        return
                    }
                    root.armed = entry.id
                    root.disarm.restart()
                }
            }
        }
    }
}
