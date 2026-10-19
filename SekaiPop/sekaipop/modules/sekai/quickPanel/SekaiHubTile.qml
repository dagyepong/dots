import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// One big tile of the Settings menu: a wide leaning plate with a coloured
// diamond holding the page's icon, its name large underneath, a line about
// what is on the page, and a big faint number in the corner, like the
// buttons of a rhythm game's main menu. Hovering lights it up with the
// accent wipe; it presses into its shadow like every other key.
//
// Pure UI: SettingsFace places six of them and turns clicked() into
// "open that page". `slot` picks the tile's colour from the five card
// colours; `badge` is a pink dot ("something is waiting", used on About
// when an update exists).
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property int number: 1
    property int slot: 0
    property bool badge: false

    // The plate's size (its shadow is drawn outside it).
    property real tileW: 400
    property real tileH: 277

    signal clicked()

    readonly property bool hovered: area.containsMouse
    readonly property color accent: Theme.attributeColors[slot % Theme.attributeColors.length]

    implicitWidth: tileW + 9
    implicitHeight: tileH + 7

    SekaiKey {
        id: key

        capW: root.tileW
        capH: root.tileH
        skew: 0.08 * Theme.settingsLean
        radius: 40
        lit: root.hovered
        hovered: root.hovered
        pressed: area.pressed
        flatShadow: Theme.quickFlat
        borderBase: 4
        borderLit: 4.5
        ringExtra: 7
        shadowBaseX: 6
        shadowBaseY: 5

        readonly property color ink: Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))

        // the big number
        Text {
            x: key.capW - implicitWidth - 46
            y: 20
            text: "0" + root.number
            color: Qt.rgba(key.ink.r, key.ink.g, key.ink.b, 0.14)
            font.family: Theme.fontFamily
            font.pixelSize: 68
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        // the diamond with the icon
        Rectangle {
            x: 88 - width / 2
            y: 100 - height / 2
            width: 66
            height: 66
            radius: 18
            rotation: 45
            color: root.accent
            border.width: 4
            border.color: key.litP > 0.5 ? Theme.colBorder : Theme.pLine
            antialiasing: true
        }

        MaterialIcon {
            x: 88 - width / 2
            y: 100 - height / 2
            size: 40
            name: root.icon
            weight: Theme.settingsIconWeight
            // Outline like every other icon (Theme.iconFill); this one used to
            // be forced solid, which filled in Bar, Desktop, Hyprland and About.
            color: Theme.colBorder
        }

        Rectangle {
            visible: root.badge
            x: 122
            y: 44
            width: 22
            height: 22
            radius: 11
            color: ScrapbookTheme.accentPink
            border.width: 3.5
            border.color: Theme.pLine
            antialiasing: true
        }

        Text {
            x: 42
            y: key.capH - 108
            width: key.capW - 84
            elide: Text.ElideRight
            text: root.label
            color: key.ink
            font.family: Theme.fontFamily
            font.pixelSize: 40
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            lineHeight: 44
            lineHeightMode: Text.FixedHeight
        }

        Text {
            x: 42
            y: key.capH - 60
            width: key.capW - 84
            elide: Text.ElideRight
            text: root.subtitle
            color: key.litP > 0.5 ? Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.78) : Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 19
            font.weight: Font.DemiBold
        }

        // three stripes between the number and the name, in the next card colours
        Repeater {
            model: 3

            delegate: Slant {
                required property int index

                x: key.capW - 132 + index * 24
                y: 124
                width: 30
                height: 27
                skew: 0.55
                radius: 3
                color: Theme.attributeColors[(root.slot + 1 + index) % Theme.attributeColors.length]
            }
        }
    }

    MouseArea {
        id: area
        x: 0
        y: 0
        width: root.tileW
        height: root.tileH
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
