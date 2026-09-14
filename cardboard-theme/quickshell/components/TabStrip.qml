// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T A B   S T R I P                                                      │
// │   tabs within a settings page                                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// Pills naming the parts of a settings page, all visible, the current one
// filled. A page with a single part gets no strip.
Item {
    id: root

    // Entries of { id, label }.
    property var tabs: []
    property string current: ""

    signal picked(string id)

    Layout.fillWidth: true
    implicitHeight: root.tabs.length > 1 ? 30 : 0
    visible: root.tabs.length > 1

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: root.tabs

            Rectangle {
                id: pill

                required property var modelData

                readonly property bool active: pill.modelData.id === root.current

                width: caption.implicitWidth + 24
                height: 26
                radius: height / 2
                color: pill.active ? Theme.accent
                    : (pillMouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface)
                border.color: pill.active ? Theme.accent : Theme.islandBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                Text {
                    id: caption

                    anchors.centerIn: parent
                    text: pill.modelData.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: pill.active ? Font.DemiBold : Font.Normal
                    color: pill.active ? Theme.accentText : Theme.textMuted

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                MouseArea {
                    id: pillMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(pill.modelData.id)
                }
            }
        }
    }
}
