import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// The Settings Panel's tile: what SettingToggle, SettingAction and
// SettingStepper are drawn with. A leaning keycap with a diamond badge for
// the icon, a name and a second line, and the same ways of lighting up and
// being pressed as the Quick Panel's tiles (see SekaiKey). Not something
// a page uses directly.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool lit: false
    // Header-button behaviour: hovering lights it up too.
    property bool hoverLights: false
    // false for a tile that holds its own buttons (the stepper).
    property bool clickable: true
    property real tileWidth: 300
    // Room kept free on the right for something placed inside the tile.
    property real textRightPad: 26

    readonly property real capH: 70
    readonly property bool hovered: area.containsMouse && clickable

    signal clicked()

    // Anything declared inside the tile goes in its content box (which leans
    // with the plate, like the icon and the writing).
    default property alias extra: key.content

    implicitWidth: tileWidth + 6
    implicitHeight: capH + 4

    // Pulses by itself when `lit` changes without a click on this tile (the
    // setting was changed from the Quick Panel, say).
    property bool keyPulse: false
    property bool suppressPulse: false

    onLitChanged: {
        if (suppressPulse)
            return
        keyPulse = true
        pulseRelease.restart()
    }

    Timer {
        id: pulseRelease
        interval: 90
        onTriggered: root.keyPulse = false
    }

    Timer {
        id: suppressGrace
        interval: 600
        onTriggered: root.suppressPulse = false
    }

    SekaiKey {
        id: key

        capW: root.tileWidth
        capH: root.capH
        skew: 0.2 * Theme.settingsLean
        radius: 26
        lit: root.lit || (root.hoverLights && root.hovered)
        hovered: root.hovered
        pressed: (area.pressed && root.clickable) || root.keyPulse
        flatShadow: Theme.quickFlat

        readonly property color ink: Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))
        readonly property real badgeX: 48

        // the diamond badge
        Rectangle {
            x: key.badgeX - width / 2
            y: (key.capH - height) / 2
            width: 33
            height: 33
            radius: 9
            rotation: 45
            color: Qt.tint(Theme.pSurfaceDivider, Qt.rgba(1, 1, 1, key.litP))
            border.width: 3
            border.color: key.litP > 0.5 ? Theme.colBorder : Theme.pLine
            antialiasing: true
        }

        MaterialIcon {
            visible: root.icon !== ""
            x: key.badgeX - width / 2
            y: (key.capH - height) / 2
            size: 22
            name: root.icon
            fill: Theme.iconFill
            color: key.ink
        }

        Column {
            x: key.badgeX + 34
            width: Math.max(10, key.capW - x - root.textRightPad)
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.label
                color: key.ink
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                lineHeight: 22
                lineHeightMode: Text.FixedHeight
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: root.subtitle !== ""
                text: root.subtitle
                color: key.litP > 0.5 ? Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.78) : Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
            }
        }
    }

    MouseArea {
        id: area
        x: 0
        y: 0
        width: root.tileWidth
        height: root.capH
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.suppressPulse = true
        onReleased: suppressGrace.restart()
        onCanceled: suppressGrace.restart()
        onClicked: root.clicked()
    }
}
