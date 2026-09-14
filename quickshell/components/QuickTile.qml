// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   Q U I C K   T I L E                                                    │
// │   a control centre toggle · icon, name and current state                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// A toggle that states what it is doing ("Bluetooth · WH-1000XM4", not
// "On"). The on state shows on the icon badge; filling the whole tile would
// turn a panel of toggles into blocks of accent.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string detail: ""
    property bool active: false
    property bool available: true

    // Tiles with a detail view get a chevron that opens it; the rest of the
    // tile still toggles.
    property bool expandable: false

    signal toggled()
    signal expanded()

    radius: Theme.radiusMedium
    opacity: root.available ? 1 : 0.45

    color: mouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface
    border.color: root.active ? Theme.accent : Theme.islandBorder
    border.width: 1

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 11

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: root.active ? Theme.accent : Theme.islandSurfaceHover

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Theme.fontMono
                font.pixelSize: 16
                color: root.active ? Theme.accentText : Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            // Room for the chevron, which sits above this row rather than in
            // the layout so it can have its own hit area.
            Layout.rightMargin: root.expandable ? 16 : 0

            Text {
                Layout.fillWidth: true
                text: root.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                Layout.fillWidth: true
                text: root.detail
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: root.active ? Theme.accent : Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    // Declared last so it sits above the tile's own mouse area.
    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 28
        visible: root.expandable

        Text {
            anchors.centerIn: parent
            text: "󰅂"
            font.family: Theme.fontMono
            font.pixelSize: 13
            color: chevron.containsMouse ? Theme.accent : Theme.textMuted

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        MouseArea {
            id: chevron
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.available
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded()
        }
    }
}
