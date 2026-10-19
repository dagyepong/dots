import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The flyout of the utility keys on a short standing bar (left / right edge).
// A standing bar has a lot to stack, so when it is too short for the long pill
// (Status_Bar `tightV`) the pill becomes one tools key, and this card opens
// from it: the keys (UtilKeys.qml, the same list the bar's pill uses) as a small
// keypad straight on the card, with a caption that names the key under the
// pointer. The frame, focus grab, pop-in and swallow come from SekaiPopup.qml;
// Bar.qml gives it `source` (the UtilButtons the keys act on).
//
// Keys that start something (screen snip, colour picker, recording, wallpapers)
// close the card after the press; the ones that flip a state (keyboard, mic, dark
// mode, power profile) leave it open so you can see them change.
SekaiPopup {
    id: root

    // The bar's UtilButtons (it owns what the keys do and show).
    property var source: null

    readonly property int pad: 16
    readonly property int columns: 4
    readonly property real innerW: Math.max(keys.implicitWidth, tab.implicitWidth)

    contentWidth: root.innerW + 2 * root.pad
    contentHeight: stack.implicitHeight + 2 * root.pad - 2

    Column {
        id: stack
        x: root.pad
        y: root.pad - 2
        width: root.innerW
        spacing: 8

        SectionTab {
            id: tab
            text: "utility keys"
        }

        // The keypad sits straight on the card (one background, not a pill inside it).
        UtilKeys {
            id: keys
            x: (stack.width - width) / 2
            src: root.source
            columns: root.columns
            keyWidth: 44
            keyHeight: 36
            iconSize: 24
            onCloseRequested: root.closeRequested()
        }

        // What the key under the pointer does.
        Text {
            width: stack.width
            height: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: keys.hint !== "" ? keys.hint : "Utility keys"
            opacity: keys.hint !== "" ? 1 : 0.55
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }
}
