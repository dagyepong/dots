import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A keycap of the media card (MediaPopup.qml): the shell's own Pill, pressing
// into its hard shadow like every other key (DiscordKey, the battery's keys).
//
//   MediaKey { icon: "skip_next"; available: p.canGoNext; onClicked: p.next() }
//
//   primary    the song's colours as a gradient (the big play key); the dark ink
//              of the plates sits on it
//   label      a word beside the icon (primary / wide keys only)
//   compact    the small square key for the card's tools (equalizer, window); same
//              outline + white ring as the big keys, just smaller
//   available  a key the player cannot do is dimmed and takes no click
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool primary: false
    property bool compact: false
    property bool available: true
    property color toneTop: Theme.accentMint
    property color toneBottom: Theme.accentCyan

    signal clicked()

    readonly property real shadow: Theme.shadowOffset

    implicitWidth: root.compact ? 38 : 80
    implicitHeight: (root.compact ? 32 : 44) + root.shadow
    opacity: root.available ? 1 : 0.4
    Behavior on opacity {
        NumberAnimation { duration: 140 }
    }

    Gradient {
        id: toneGradient
        GradientStop { position: 0.0; color: Qt.lighter(root.toneTop, area.containsMouse ? 1.08 : 1) }
        GradientStop { position: 1.0; color: Qt.lighter(root.toneBottom, area.containsMouse ? 1.08 : 1) }
    }

    Pill {
        anchors.fill: parent
        cornerRadius: root.compact ? 12 : 15
        ringWidth: 5
        shadowDy: root.shadow
        fillColor: area.containsMouse && root.available ? Theme.surfaceHover : Theme.surface
        fillGradient: root.primary ? toneGradient : null
        pressed: area.pressed && root.available

        Row {
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                fill: 0
                weight: 500
                size: root.compact ? 16 : 24
                color: root.primary ? Theme.colBorder : Theme.ink
            }

            Text {
                visible: root.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: root.primary ? Theme.colBorder : Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
